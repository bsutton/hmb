/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// --------------------------------------------------------------
// lib/src/api/upload_photos_in_backup.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:googleapis/drive/v3.dart' as gdrive show File;
import 'package:http/http.dart' as http;

import '../../progress_update.dart';
import '../google_drive_api.dart';
import 'photo_sync_params.dart';
import 'photo_sync_service.dart';

const _driveMetadataTimeout = Duration(seconds: 45);
const _photoUploadTimeout = Duration(minutes: 2);

/// Uploads the given photos to Google Drive, sending progress updates.
Future<void> uploadPhotosInBackup({
  required SendPort sendPort,
  required Map<String, String> authHeaders,
  required List<PhotoPayload> photoPayloads,
  required List<PhotoDeletePayload> deletePayloads,
}) async {
  final totalPhotos = photoPayloads.length;
  final totalDeletes = deletePayloads.length;
  final stageCount = totalPhotos + totalDeletes + 2;
  var stageNo = 1;
  if (totalPhotos == 0 && totalDeletes == 0) {
    sendPort.send(ProgressUpdate('No photos to sync', stageNo++, stageCount));
    return;
  }

  // Init Drive API
  final driveApi = await GoogleDriveApi.fromHeaders(authHeaders);
  try {
    final photoSyncFolderId = await _withTimeout(
      driveApi.getPhotoSyncFolder(),
      timeout: _driveMetadataTimeout,
      operation: 'finding the Google Drive photo sync folder',
    );

    for (var i = 0; i < totalDeletes; i++) {
      final payload = deletePayloads[i];
      sendPort.send(
        ProgressUpdate(
          'Deleting photo (${i + 1}/$totalDeletes)',
          stageNo++,
          stageCount,
        ),
      );
      final deleted = await _withTimeout(
        _deleteRemoteByPhotoId(driveApi: driveApi, photoId: payload.photoId),
        timeout: _driveMetadataTimeout,
        operation: 'deleting remote photo ${payload.photoId}',
      );
      if (deleted) {
        sendPort.send(PhotoDeleted(payload.photoDeleteQueueId));
      } else {
        // Treat missing as deleted;
        sendPort.send(PhotoDeleted(payload.photoDeleteQueueId));
      }
    }

    for (var i = 0; i < totalPhotos; i++) {
      final photoPayload = photoPayloads[i];

      sendPort.send(
        ProgressUpdate(
          'Preparing photo (${i + 1}/$totalPhotos)',
          stageNo++,
          stageCount,
        ),
      );

      final file = File(photoPayload.absolutePathToLocalPhoto);
      if (!file.existsSync()) {
        // this should only be an issue for me as I have
        // old photo records for which I lost the photo
        // so for now we just mark these photos as synced.
        sendPort
          ..send(
            PhotoUploaded(photoPayload.id, photoPayload.pathToCloudStorage, 3),
          )
          ..send(
            ProgressUpdate(
              'Photo (${i + 1}/$totalPhotos) skipped as missing',
              stageNo++,
              stageCount,
            ),
          );
        continue;
      }

      // Create folder hierarchy from pathToCloudStorage (excluding file name)
      final parts = photoPayload.pathToCloudStorage.split('/');
      final cloudStorageParts = parts.take(parts.length - 1);
      final fileName = parts.last;

      var parentId = photoSyncFolderId;
      for (final part in cloudStorageParts) {
        parentId = await _withTimeout(
          driveApi.getOrCreateFolderId(part, parentId: parentId),
          timeout: _driveMetadataTimeout,
          operation: 'creating Google Drive folder "$part"',
        );
      }

      // Upload file to final destination
      final metadata = jsonEncode({
        'name': '${photoPayload.id}:$fileName',
        'parents': [parentId],
        'properties': {
          // custom metadata key “photoId” holding your photo’s ID
          'photoId': photoPayload.id.toString(),
        },
      });

      final initResp = await _withTimeout(
        driveApi.send(
          http.Request(
              'POST',
              Uri.parse(
                'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
              ),
            )
            ..headers['Content-Type'] = 'application/json; charset=UTF-8'
            ..body = metadata,
        ),
        timeout: _driveMetadataTimeout,
        operation: 'starting upload for photo ${photoPayload.id}',
      );

      if (initResp.statusCode < 200 || initResp.statusCode >= 300) {
        final body = await initResp.stream.bytesToString();
        final reason = initResp.reasonPhrase ?? '';
        throw HttpException(
          'Failed to initialize resumable upload for photo ${photoPayload.id}: '
          '${initResp.statusCode} $reason ${body.trim()}',
        );
      }

      final uploadUrl = initResp.headers['location'];
      if (uploadUrl == null) {
        throw StateError(
          'Google Drive did not return an upload URL for photo '
          '${photoPayload.id}.',
        );
      }

      final totalBytes = await file.length();
      sendPort.send(
        ProgressUpdate(
          'Sending photo (${i + 1}/$totalPhotos, '
          '${_formatBytes(totalBytes)})',
          stageNo,
          stageCount,
        ),
      );
      final uploadStreamResponse = await _uploadFileWithProgress(
        driveApi: driveApi,
        uploadUrl: uploadUrl,
        file: file,
        totalBytes: totalBytes,
        sendPort: sendPort,
        stageNo: stageNo,
        stageCount: stageCount,
        photoIndex: i + 1,
        totalPhotos: totalPhotos,
        photoId: photoPayload.id,
      );

      final uploadResp = await _withTimeout(
        http.Response.fromStream(uploadStreamResponse),
        timeout: _photoUploadTimeout,
        operation: 'reading upload response for photo ${photoPayload.id}',
      );

      if (uploadResp.statusCode != 200 && uploadResp.statusCode != 201) {
        throw HttpException(
          'Photo ${photoPayload.id} upload failed: ${uploadResp.statusCode} '
          '${uploadResp.reasonPhrase ?? ''} ${uploadResp.body.trim()}',
        );
      }

      final fileJson = jsonDecode(uploadResp.body) as Map<String, dynamic>;
      final cloudFileId = fileJson['id'] as String?;
      final cloudMd5 = fileJson['md5Checksum'] as String?;
      final cloudModifiedDate = DateTime.tryParse(
        fileJson['modifiedTime'] as String? ?? '',
      );
      sendPort
        ..send(
          PhotoUploaded(
            photoPayload.id,
            photoPayload.pathToCloudStorage,
            3,
            cloudFileId: cloudFileId,
            cloudMd5: cloudMd5,
            cloudModifiedDate: cloudModifiedDate,
          ),
        )
        ..send(
          ProgressUpdate(
            'Photo (${i + 1}/$totalPhotos) synced',
            stageNo++,
            stageCount,
          ),
        );
      // Used to test that meta data uploads work.
      // await hasPhotoIdProperty(fileId: cloudFileId!, driveApi: driveApi);
    }

    sendPort.send(ProgressUpdate('Photo sync completed', stageNo, stageNo));
  } finally {
    driveApi.close();
  }
}

Future<T> _withTimeout<T>(
  Future<T> future, {
  required Duration timeout,
  required String operation,
}) => future.timeout(
  timeout,
  onTimeout: () => throw TimeoutException(
    'Timed out after ${timeout.inSeconds}s while $operation.',
  ),
);

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

Future<http.StreamedResponse> _uploadFileWithProgress({
  required GoogleDriveApi driveApi,
  required String uploadUrl,
  required File file,
  required int totalBytes,
  required SendPort sendPort,
  required int stageNo,
  required int stageCount,
  required int photoIndex,
  required int totalPhotos,
  required int photoId,
}) async {
  final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl))
    ..headers['Content-Type'] = 'image/jpeg'
    ..contentLength = totalBytes;

  final responseFuture = _withTimeout(
    driveApi.send(request),
    timeout: _photoUploadTimeout,
    operation: 'uploading photo $photoId',
  );

  try {
    await _withTimeout(
      _writeFileToRequestWithProgress(
        file: file,
        sink: request.sink,
        totalBytes: totalBytes,
        sendPort: sendPort,
        stageNo: stageNo,
        stageCount: stageCount,
        photoIndex: photoIndex,
        totalPhotos: totalPhotos,
      ),
      timeout: _photoUploadTimeout,
      operation: 'sending photo $photoId data',
    );
  } catch (_) {
    unawaited(request.sink.close());
    rethrow;
  }

  return responseFuture;
}

Future<void> _writeFileToRequestWithProgress({
  required File file,
  required StreamSink<List<int>> sink,
  required int totalBytes,
  required SendPort sendPort,
  required int stageNo,
  required int stageCount,
  required int photoIndex,
  required int totalPhotos,
}) async {
  var sentBytes = 0;
  var lastPercentBucket = -1;

  await for (final chunk in file.openRead()) {
    sink.add(chunk);
    sentBytes += chunk.length;

    final percent = totalBytes == 0 ? 100 : sentBytes * 100 ~/ totalBytes;
    final percentBucket = percent ~/ 10;
    if (percentBucket != lastPercentBucket || sentBytes == totalBytes) {
      lastPercentBucket = percentBucket;
      sendPort.send(
        ProgressUpdate(
          'Sending photo ($photoIndex/$totalPhotos, $percent%, '
          '${_formatBytes(totalBytes)})',
          stageNo,
          stageCount,
        ),
      );
    }
  }

  unawaited(sink.close());
}

/// Returns `true` if the given file has a “photoId” property set.
Future<bool> hasPhotoIdProperty({
  required String fileId,
  required GoogleDriveApi driveApi,
}) async {
  // Only request the properties field to keep the payload small
  final file =
      await driveApi.files.get(fileId, $fields: 'properties') as gdrive.File;
  // properties may be null if none were ever set
  final props = file.properties;
  return props != null && props.containsKey('photoId');
}

Future<bool> _deleteRemoteByPhotoId({
  required GoogleDriveApi driveApi,
  required int photoId,
}) async {
  final idStr = photoId.toString();
  final qByProp =
      "properties has { key='photoId' and value='$idStr' } and trashed=false";
  final res = await _withTimeout(
    driveApi.files.list(q: qByProp, $fields: 'files(id, name)', pageSize: 100),
    timeout: _driveMetadataTimeout,
    operation: 'finding remote photo $photoId for deletion',
  );
  final files = res.files ?? const <gdrive.File>[];
  if (files.isEmpty) {
    return false;
  }
  for (final file in files) {
    if (file.id == null) {
      continue;
    }
    await _withTimeout(
      driveApi.files.delete(file.id!),
      timeout: _driveMetadataTimeout,
      operation: 'deleting Google Drive file ${file.id}',
    );
  }
  return true;
}

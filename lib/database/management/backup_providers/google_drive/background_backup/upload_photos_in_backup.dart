/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// --------------------------------------------------------------
// lib/src/api/upload_photos_in_backup.dart
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:googleapis/drive/v3.dart' as gdrive show File;
import 'package:http/http.dart' as http;

import '../../progress_update.dart';
import '../api.dart';
import 'photo_sync_params.dart';
import 'photo_sync_service.dart';

/// Uploads the given photos to Google Drive, sending progress updates.
Future<void> uploadPhotosInBackup({
  required SendPort sendPort,
  required Map<String, String> authHeaders,
  required List<PhotoPayload> photoPayloads,
}) async {
  final totalPhotos = photoPayloads.length;
  final stageCount = totalPhotos + 2;
  var stageNo = 1;
  if (totalPhotos == 0) {
    sendPort.send(ProgressUpdate('No photos to sync', stageNo++, stageCount));
    return;
  }

  // Init Drive API
  final driveApi = await GoogleDriveApi.fromHeaders(authHeaders);
  final photoSyncFolderId = await driveApi.getPhotoSyncFolder();

  for (var i = 0; i < totalPhotos; i++) {
    final photoPayload = photoPayloads[i];

    sendPort.send(
      ProgressUpdate(
        'Uploading photo (${i + 1}/$totalPhotos)',
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
            'Photo ${photoPayload.id} skipped as missing',
            stageNo++,
            stageCount,
          ),
        );
      continue;
    }

    // Create folder hierarchy from pathToCloudStorage (excluding the file name)
    final parts = photoPayload.pathToCloudStorage.split('/');
    final cloudStorageParts = parts.take(parts.length - 1);
    final fileName = parts.last;

    var parentId = photoSyncFolderId;
    for (final part in cloudStorageParts) {
      parentId = await driveApi.getOrCreateFolderId(
        part,
        parentFolderId: parentId,
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

    final initResp = await driveApi.send(
      http.Request(
          'POST',
          Uri.parse(
            'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
          ),
        )
        ..headers['Content-Type'] = 'application/json; charset=UTF-8'
        ..body = metadata,
    );

    final uploadUrl = initResp.headers['location'];
    if (uploadUrl == null) {
      continue;
    }

    final bytes = await file.readAsBytes();
    final uploadStreamResponse = await driveApi.send(
      http.Request('PUT', Uri.parse(uploadUrl))
        ..headers['Content-Type'] = 'image/jpeg'
        ..bodyBytes = bytes,
    );

    final uploadResp = await http.Response.fromStream(uploadStreamResponse);

    if (uploadResp.statusCode == 200 || uploadResp.statusCode == 201) {
      sendPort
        ..send(
          PhotoUploaded(photoPayload.id, photoPayload.pathToCloudStorage, 3),
        )
        ..send(
          ProgressUpdate(
            'Photo ${photoPayload.id} synced',
            stageNo++,
            stageCount,
          ),
        );
      // final fileJson = jsonDecode(uploadResp.body) as Map<String, dynamic>;
      // final fileId = fileJson['id'] as String;
      // Used to test that meta data uploads work.
      // await hasPhotoIdProperty(fileId: fileId, driveApi: driveApi);
    }
  }

  driveApi.close();
  sendPort.send(ProgressUpdate('Photo sync completed', stageNo, stageNo));
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

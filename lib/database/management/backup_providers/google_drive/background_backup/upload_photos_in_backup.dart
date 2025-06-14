// --------------------------------------------------------------
// lib/src/api/upload_photos_in_backup.dart
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

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
  final backupsFolderId = await driveApi.getBackupFolder();

  for (var i = 0; i < totalPhotos; i++) {
    final photoPayload = photoPayloads[i];

    sendPort.send(
      ProgressUpdate(
        'Uploading photo (${i + 1}/$totalPhotos)',
        stageNo++,
        stageCount,
      ),
    );

    final file = File(photoPayload.absolutePathToPhoto);
    if (!file.existsSync()) {
      // this should only be an issue for me as I have
      // old photo records for which I lost the photo
      // so for now we just mark these photos as synced.
      sendPort
        ..send(PhotoUploaded(photoPayload.id, photoPayload.pathToCloudStorage))
        ..send(
          ProgressUpdate(
            'Photo ${photoPayload.id} skipped as missing',
            stageNo++,
            stageCount,
          ),
        );
      continue;
    }

    // Create folder hierarchy from storagePath (excluding the file name)
    final parts = photoPayload.pathToCloudStorage.split('/');
    final folderParts = parts.take(parts.length - 1);
    final fileName = parts.last;

    var parentId = backupsFolderId;
    for (final part in folderParts) {
      parentId = await driveApi.getOrCreateFolderId(
        part,
        parentFolderId: parentId,
      );
    }

    // Upload file to final destination
    final metadata = jsonEncode({
      'name': '${photoPayload.id}:$fileName',
      'parents': [parentId],
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
    final uploadResp = await driveApi.send(
      http.Request('PUT', Uri.parse(uploadUrl))
        ..headers['Content-Type'] = 'image/jpeg'
        ..bodyBytes = bytes,
    );

    if (uploadResp.statusCode == 200 || uploadResp.statusCode == 201) {
      sendPort
        ..send(PhotoUploaded(photoPayload.id, photoPayload.pathToCloudStorage))
        ..send(
          ProgressUpdate(
            'Photo ${photoPayload.id} synced',
            stageNo++,
            stageCount,
          ),
        );
    }
  }

  driveApi.close();
  sendPort.send(ProgressUpdate('Photo sync completed', stageNo, stageNo));
}

// --------------------------------------------------------------
// lib/src/api/upload_photos_in_backup.dart
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
  final photosFolderId = await driveApi.getOrCreateFolderId(
    'photos',
    parentFolderId: backupsFolderId,
  );

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
      continue;
    }

    final monthFolderName = DateFormat(
      'yyyy-MM',
    ).format(photoPayload.createdAt);
    final monthFolderId = await driveApi.getOrCreateFolderId(
      monthFolderName,
      parentFolderId: photosFolderId,
    );

    // Resumable upload init
    final metadata = jsonEncode({
      'name': '${photoPayload.id}:${file.uri.pathSegments.last}',
      'parents': [monthFolderId],
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
        ..send(PhotoUploaded(photoPayload.id))
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

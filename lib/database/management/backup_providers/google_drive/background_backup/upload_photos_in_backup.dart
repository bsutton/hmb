// --------------------
// Imports
// --------------------

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../../../dao/dao.g.dart';
import '../api.dart';
import 'backup_params.dart';
import 'progress_update.dart';

Future<void> uploadPhotosInBackup(BackupParams params) async {
  final sendPort = params.sendPort;
  final newPhotos = await DaoPhoto().getNewPhotos();
  final totalPhotos = newPhotos.length;
  if (totalPhotos == 0) {
    sendPort.send(
      ProgressUpdate(
        'No new photos to backup',
        params.progressStageEnd,
        params.progressStageEnd,
      ),
    );
    return;
  }

  // Initialize the Drive API.
  final driveApi = await GoogleDriveApi.fromHeaders(params.authHeaders);
  // Build folder structure: hmb → backups → photos.
  final hmbFolderId = await driveApi.getOrCreateFolderId('hmb');
  final backupsFolderId = await driveApi.getOrCreateFolderId(
    'backups',
    parentFolderId: hmbFolderId,
  );
  final photosFolderId = await driveApi.getOrCreateFolderId(
    'photos',
    parentFolderId: backupsFolderId,
  );

  var processed = 0;
  for (final photo in newPhotos) {
    final stageNo =
        params.progressStageStart +
        ((processed / totalPhotos) *
                (params.progressStageEnd - params.progressStageStart))
            .toInt();
    sendPort.send(
      ProgressUpdate(
        'Uploading photo (${processed + 1}/$totalPhotos)',
        stageNo,
        params.progressStageEnd,
      ),
    );

    final photoFile = File(photo.filePath);
    if (!photoFile.existsSync()) {
      processed++;
      continue;
    }

    // Create a monthly subfolder based on the photo's creation date.
    final monthFolderName = DateFormat('yyyy-MM').format(photo.createdDate);
    final monthFolderId = await driveApi.getOrCreateFolderId(
      monthFolderName,
      parentFolderId: photosFolderId,
    );

    // Prepare metadata for the file.
    final metadata = {
      'name': photoFile.uri.pathSegments.last,
      'parents': [monthFolderId],
    };

    // Initiate a resumable upload session.
    final uri = Uri.parse(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
    );
    final initRequest =
        http.Request('POST', uri)
          ..headers['Content-Type'] = 'application/json; charset=UTF-8'
          ..body = jsonEncode(metadata);

    final initResponse = await driveApi.send(initRequest);
    if (initResponse.statusCode != 200 && initResponse.statusCode != 201) {
      sendPort.send(
        ProgressUpdate(
          'Error initiating upload for photo ${photo.id}',
          stageNo,
          params.progressStageEnd,
        ),
      );
      processed++;
      continue;
    }
    final uploadUrl = initResponse.headers['location'];
    if (uploadUrl == null) {
      sendPort.send(
        ProgressUpdate(
          'No upload URL for photo ${photo.id}',
          stageNo,
          params.progressStageEnd,
        ),
      );
      processed++;
      continue;
    }

    // Upload the photo.
    final fileBytes = await photoFile.readAsBytes();
    final uploadRequest =
        http.Request('PUT', Uri.parse(uploadUrl))
          ..headers['Content-Type'] = 'image/jpeg'
          ..bodyBytes = fileBytes;
    final uploadResponse = await driveApi.send(uploadRequest);
    if (uploadResponse.statusCode == 200 || uploadResponse.statusCode == 201) {
      // Mark photo as backed up in the database.
      await DaoPhoto().updatePhotoBackupStatus(photo.id);
      sendPort.send(
        ProgressUpdate(
          'Uploaded photo ${photo.id}',
          stageNo,
          params.progressStageEnd,
        ),
      );
    } else {
      sendPort.send(
        ProgressUpdate(
          'Failed uploading photo ${photo.id}',
          stageNo,
          params.progressStageEnd,
        ),
      );
    }
    processed++;
  }
  driveApi.close();
}

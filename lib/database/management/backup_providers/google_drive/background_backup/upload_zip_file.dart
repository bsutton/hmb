// --------------------
// Imports
// --------------------

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart';

import '../api.dart';
import 'backup_params.dart';
import 'progress_update.dart';
import 'track_progress.dart';

Future<void> uploadZipFile(BackupParams params) async {
  final sendPort = params.sendPort;
  final fileToUpload = File(params.pathToZip);
  final fileName = basename(params.pathToZip);
  final fileSize = await fileToUpload.length();
  const chunkSize = 256 * 1024 * 5; // 5MB chunks
  var start = 0;

  final driveApi = await GoogleDriveApi.fromHeaders(params.authHeaders);
  final backupsFolderId = await driveApi.getBackupFolder();
  final uploadUrl = await _initiateResumableUpload(
    fileName,
    backupsFolderId,
    driveApi,
  );

  while (start < fileSize) {
    final end = (start + chunkSize < fileSize) ? start + chunkSize : fileSize;
    final totalChunkLength = end - start;

    // Create a stream for the current chunk and wrap it to track progress.
    final fileStream = fileToUpload.openRead(start, end);
    final progressStream = trackProgress(fileStream, totalChunkLength, (
      progress,
    ) {
      sendPort.send(
        ProgressUpdate.upload(
          'Uploading backup: ${progress.toStringAsFixed(0)}%',
        ),
      );
    });

    final headers = {
      'Content-Type': 'application/zip',
      'Content-Range': 'bytes $start-${end - 1}/$fileSize',
    };

    final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl))
      ..headers.addAll(headers);
    await for (final data in progressStream) {
      request.sink.add(data);
    }
    // We can't await the close as it will never return until the
    // below driveApi.send completes so we deadlock.
    // We don't actually need to wait for the sink to close
    // so we just unawait it.
    unawaited(request.sink.close());

    final response = await driveApi.send(request);
    if (response.statusCode == 308) {
      final range = response.headers['range'];
      final newStart = _parseRange(range);
      start = newStart > start ? newStart : end;
    } else if (response.statusCode == 200 || response.statusCode == 201) {
      sendPort.send(ProgressUpdate.upload('Upload complete'));
      break;
    } else {
      sendPort.send(
        ProgressUpdate.upload(
          'Failed to upload chunk. Status: ${response.statusCode}',
        ),
      );
      return;
    }
  }
  driveApi.close();
}

// --------------------
// _initiateResumableUpload: Helper to start a resumable upload session.
// --------------------
Future<String> _initiateResumableUpload(
  String fileName,
  String folderId,
  GoogleDriveApi api,
) async {
  final uri = Uri.parse(
    'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
  );
  final metadata = {
    'name': fileName,
    'parents': [folderId],
  };

  final request = http.Request('POST', uri)
    ..headers['Content-Type'] = 'application/json; charset=UTF-8'
    ..body = jsonEncode(metadata);

  final response = await api.send(request);
  if (response.statusCode != 200 && response.statusCode != 201) {
    final body = await response.stream.bytesToString();
    throw Exception(
      'Failed to initiate resumable upload. Status: ${response.statusCode}, Body: $body',
    );
  }

  final uploadUrl = response.headers['location'];
  if (uploadUrl == null) {
    throw Exception('No upload URL returned in response headers');
  }
  return uploadUrl;
}

// --------------------
// _parseRange: Parses the range header returned by Drive during chunked uploads.
// --------------------
int _parseRange(String? rangeHeader) {
  if (rangeHeader == null) {
    return 0;
  }
  final parts = rangeHeader.split('-');
  if (parts.length == 2) {
    final endRange = int.tryParse(parts[1]);
    if (endRange != null) {
      return endRange + 1;
    }
  }
  return 0;
}

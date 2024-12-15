import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:sentry/sentry.dart';

import '../backup_provider.dart';
import 'api.dart';

class ZipUploader {
  ZipUploader({
    required this.pathToZip,
    required this.provider,
  });

  String pathToZip;

  BackupProvider provider;

  Future<void> upload() async {
    await _uploadToDrive();
  }

  Future<void> _uploadToDrive() async {
    final completer = Completer<void>();
    final receivePort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();

    // Listen for progress updates from the isolate
    receivePort.listen((message) {
      if (message is ProgressUpdate) {
        provider.emitProgress(
          message.stageDescription,
          5,
          6,
        );
      }
    });

    errorPort.listen((message) {
      Sentry.captureException(message);
      completer.completeError(message as Object);
    });
    exitPort.listen((message) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    /// auth must occur in the main isolate as a UI may be required.
    final driveAuth = await GoogleDriveAuth.init();

    // Start the upload isolate
    await Isolate.spawn(
      _uploadFile,
      _UploadParams(
          pathToZippedBackup: pathToZip,
          sendPort: receivePort.sendPort,
          token: RootIsolateToken.instance!,
          authHeaders: driveAuth.authHeaders),
      onError: errorPort.sendPort,
      onExit: exitPort.sendPort,
    );

    // Wait for the isolate to finish
    await completer.future;

    receivePort.close();
    errorPort.close();
    exitPort.close();
  }

  static Future<void> _uploadFile(_UploadParams params) async {
    final pathToZippedBackup = params.pathToZippedBackup;
    final sendPort = params.sendPort;
    final GoogleDriveApi driveApi;
    try {
      BackgroundIsolateBinaryMessenger.ensureInitialized(params.token);

      await Sentry.init(
        (options) {
          options
            ..dsn =
                'https://17bb41df4a5343530bfcb92553f4c5a7@o4507706035994624.ingest.us.sentry.io/4507706038157312'
            ..tracesSampleRate = 1.0;
        },
      );

      final fileToUpload = File(pathToZippedBackup);
      final fileName = basename(pathToZippedBackup);
      final fileSize = await fileToUpload.length();
      const chunkSize = 256 * 1024 * 5; // 5MB chunks
      var start = 0;
      var bytesSent = 0;

      // final http.Client client;
      driveApi = await GoogleDriveApi.fromHeaders(params.authHeaders);

      final backupsFolderId = await driveApi.getBackupFolder();

      // // Initiate resumable upload session
      // final file = drive.File()
      //   ..name = fileName
      //   ..parents = [backupsFolderId];

      // final client = http.Client();
      // Get the upload URL for this file.
      final uploadUrl =
          await initiateResumableUpload(fileName, backupsFolderId, driveApi);

      // Upload the file in chunks
      while (start < fileSize) {
        final end =
            (start + chunkSize < fileSize) ? start + chunkSize : fileSize;
        final chunkStream =
            fileToUpload.openRead(start, end).asBroadcastStream();

        // Update headers for the current chunk
        final headers = {
          'Content-Type': 'application/zip',
          'Content-Range': 'bytes $start-${end - 1}/$fileSize',
        };

        // Send the chunk
        final request = http.Request('PUT', Uri.parse(uploadUrl))
          ..headers.addAll(headers)
          ..bodyBytes = await http.ByteStream(chunkStream).toBytes();

        final progress = (bytesSent / fileSize) * 100;
        sendPort.send(ProgressUpdate.upload(
          'Uploading backup: ${progress.toStringAsFixed(0)}%',
        ));

        final response = await driveApi.send(request);

        // Check if the chunk was uploaded successfully
        if (response.statusCode == 308) {
          // Chunk uploaded successfully
          final range = response.headers['range'];
          start = _parseRange(range);
          bytesSent += await http.ByteStream(chunkStream)
              .fold<int>(0, (previous, element) => previous + element.length);
        } else if (response.statusCode == 200 || response.statusCode == 201) {
          // Upload completed successfully
          sendPort.send(ProgressUpdate.upload('Upload complete'));
          // Isolate.exit();
          break; // Exit the loop as the upload is complete
        } else {
          // Handle errors or resume from where it left off
          sendPort.send(ProgressUpdate.upload(
              'Failed to upload chunk. Status code: ${response.statusCode}'));
          return;
        }
      }
    } catch (e, st) {
      await Sentry.captureException(e, stackTrace: st);
      sendPort.send(ProgressUpdate.upload('Upload failed: $e'));
      rethrow;
    }
    driveApi.close();
    await Sentry.close();

    /// something is holding the isolate up so for
    /// now we force it to terminate.
    /// Best guess is something to do with the gdrive connection.
    Isolate.exit();
  }

  static Future<String> initiateResumableUpload(
    String fileName,
    String folderId,
    GoogleDriveApi api,
  ) async {
    final uri = Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable');
    final metadata = {
      'name': fileName,
      'parents': [folderId],
    };

    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json; charset=UTF-8'
      // ..headers['Authorization'] = 'Bearer $accessToken'
      ..body = jsonEncode(metadata);

    final response = await api.send(request);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = await response.stream.bytesToString();
      throw Exception(
          'Failed to initiate resumable upload. Status: ${response.statusCode}, Body: $body');
    }

    // The 'Location' header contains the resumable upload URL
    final uploadUrl = response.headers['location'];
    if (uploadUrl == null) {
      throw Exception('No upload URL returned in response headers');
    }

    return uploadUrl;
  }

  static int _parseRange(String? rangeHeader) {
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
}

class _UploadParams {
  _UploadParams({
    required this.pathToZippedBackup,
    required this.sendPort,
    required this.token,
    required this.authHeaders,
  });
  final String pathToZippedBackup;
  final SendPort sendPort;
  final RootIsolateToken token;

  final Map<String, String> authHeaders;
}

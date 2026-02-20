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

// lib/src/providers/google_drive_backup_provider.dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:dcli_core/dcli_core.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart';
import 'package:sentry/sentry.dart';

import '../../../../../util/dart/exceptions.dart';
import '../../../../../util/dart/paths.dart';
import '../../backup.dart';
import '../../backup_provider.dart';
import '../google_drive_api.dart';
import '../google_drive_auth.dart';
import 'backup_params.dart';
import 'photo_sync_service.dart';
import 'progress_update.dart';
import 'upload_zip_file.dart';

class GoogleDriveBackupProvider extends BackupProvider {
  GoogleDriveBackupProvider(super.databaseFactory);

  @override
  String get name => 'Google Drive';

  @override
  Future<void> deleteBackup(Backup backupToDelete) async {
    try {
      final driveApi = await GoogleDriveApi.selfAuth();
      final backupsFolderId = await driveApi.getBackupFolder();
      final fileName = basename(backupToDelete.pathTo);
      final q =
          """'$backupsFolderId' in parents and name='$fileName' and trashed=false""";
      final filesList = await driveApi.files.list(q: q);
      final files = filesList.files ?? [];
      if (files.isEmpty) {
        throw BackupException('Backup file not found: $fileName');
      }
      final fileId = files.first.id;
      await driveApi.files.delete(fileId!);
    } catch (e) {
      throw BackupException('Error deleting backup from Google Drive: $e');
    }
  }

  @override
  Future<File> fetchBackup(Backup backup) async {
    try {
      final driveApi = await GoogleDriveApi.selfAuth();
      final media =
          (await driveApi.files.get(
                backup.id,
                downloadOptions: drive.DownloadOptions.fullMedia,
              ))
              as drive.Media;
      return saveStreamToFile(media.stream, createTempFile());
    } catch (e) {
      throw BackupException('Error downloading backup from Google Drive: $e');
    }
  }

  Future<File> saveStreamToFile(
    Stream<List<int>> stream,
    String filePath,
  ) async {
    final file = File(filePath);
    final sink = file.openWrite();
    try {
      await stream.pipe(sink);
    } finally {
      await sink.close();
    }
    return File(filePath);
  }

  @override
  Future<List<Backup>> getBackups() async {
    try {
      final driveApi = await GoogleDriveApi.selfAuth();
      final folderId = await driveApi.getBackupFolder();
      final q = "'$folderId' in parents and trashed=false";
      final filesList = await driveApi.files.list(
        q: q,
        orderBy: 'createdTime desc,name',
        $fields: 'files(id, name, size, createdTime)',
      );
      final backupFiles = filesList.files ?? [];
      final entries =
          backupFiles
              .map(
                (file) => Backup(
                  id: file.id ?? '',
                  when: file.createdTime?.toLocal() ?? DateTime.now(),
                  size: file.size ?? 'unknown',
                  status: 'good',
                  pathTo: file.name ?? 'Unknown',
                  error: 'none',
                ),
              )
              .toList()
            ..sort((a, b) {
              final whenCompare = b.when.compareTo(a.when);
              return whenCompare != 0
                  ? whenCompare
                  : b.pathTo.compareTo(a.pathTo);
            });
      return entries;
    } catch (e) {
      throw BackupException('Error listing backups from Google Drive: $e');
    }
  }

  @override
  Future<BackupResult> store({
    required String pathToDatabaseCopy,
    required String pathToZippedBackup,
    required int version,
  }) async {
    try {
      emitProgress('Starting Google Drive backup', 1, 3);

      // Spawn a single isolate to perform the entire backup.
      final receivePort = ReceivePort();
      final errorPort = ReceivePort();
      final exitPort = ReceivePort();

      final params = BackupParams(
        sendPort: receivePort.sendPort,
        pathToZip: pathToZippedBackup,
        pathToBackupFile: pathToDatabaseCopy,
        authHeaders: (await GoogleDriveAuth.instance()).authHeaders,
        progressStageStart: 1,
        progressStageEnd: 3,
      );

      await Isolate.spawn(
        _performDriveBackup,
        params,
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
        debugName: 'google drive backup',
      );

      errorPort.listen((e) => emitProgress(r'Error: $e', 3, 3));
      receivePort.listen((msg) {
        if (msg is ProgressUpdate) {
          emitProgress(msg.stageDescription, msg.stageNo, msg.stageCount);
        }
      });

      await exitPort.first;
      emitProgress('Backup completed', 3, 3);
      receivePort.close();
      errorPort.close();
      exitPort.close();

      return BackupResult(
        pathToSource: pathToDatabaseCopy,
        pathToBackup: pathToZippedBackup,
        success: true,
      );
    } catch (e, st) {
      unawaited(Sentry.captureException(e, stackTrace: st));
      throw BackupException('Error uploading backup to Google Drive: $e');
    }
  }

  // --------------------
  // _performDriveBackup
  // The isolate entry point that performs the entire backup operation.
  // --------------------
  static Future<void> _performDriveBackup(BackupParams params) async {
    await Sentry.init((options) {
      options
        ..dsn =
            'https://17bb41df4a5343530bfcb92553f4c5a7@o4507706035994624.ingest.us.sentry.io/4507706038157312'
        ..tracesSampleRate = 1.0;
    });

    final sendPort = params.sendPort;

    try {
      // Step 1: Zip the database.
      sendPort.send(ProgressUpdate('Zipping DB...', 1, 3));
      final encoder = ZipFileEncoder()..create(params.pathToZip);
      await encoder.addFile(File(params.pathToBackupFile));
      await encoder.close();

      sendPort.send(ProgressUpdate('Uploading backup file...', 2, 3));
      await uploadZipFile(params);

      sendPort.send(ProgressUpdate('Backup uploaded', 3, 3));
    } catch (e) {
      sendPort.send(ProgressUpdate(r'Error during backup: $e', 3, 3));
    }
    Isolate.exit();
  }

  /// Launches the photo sync process in its own isolate.
  @override
  Future<void> syncPhotos() => PhotoSyncService().start();

  @override
  Future<String> get photosRootPath => getPhotosRootPath();

  @override
  Future<String> get backupLocation async =>
      'Google Drive: ${useDebugPath ? '/hmb/debug/backups/' : '/hmb/backups'}';

  @override
  set useDebugPath(bool bool) => kDebugMode;
}

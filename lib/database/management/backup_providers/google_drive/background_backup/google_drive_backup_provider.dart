// --------------------
// Imports
// --------------------

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:dcli_core/dcli_core.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite_common/sqflite.dart' as sql;

import '../../../../../util/exceptions.dart';
import '../../../../../util/paths.dart'
    if (dart.library.ui) '../../../../../util/paths_flutter.dart';
import '../../backup.dart';
import '../../backup_provider.dart';
import '../api.dart';
import 'backup_params.dart';
import 'progress_update.dart';
import 'upload_photos_in_backup.dart';
import 'upload_zip_file.dart';

class GoogleDriveBackupProvider extends BackupProvider {
  GoogleDriveBackupProvider(super.databaseFactory);

  @override
  String get name => 'Google Drive Backup';

  @override
  Future<void> deleteBackup(Backup backupToDelete) async {
    try {
      final driveApi = await GoogleDriveApi.selfAuth();
      final backupsFolderId = await driveApi.getBackupFolder();
      final fileName = basename(backupToDelete.pathTo);
      final q =
          "'$backupsFolderId' in parents and name='$fileName' and trashed=false";
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
      final backupsFolderId = await driveApi.getBackupFolder();
      final q = "'$backupsFolderId' in parents and trashed=false";
      final filesList = await driveApi.files.list(
        q: q,
        $fields: 'files(id, name, size, createdTime)',
      );
      final backupFiles = filesList.files ?? [];
      return backupFiles
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
          .toList();
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
      emitProgress('Starting Google Drive backup', 5, 6);

      // Spawn a single isolate to perform the entire backup.
      final receivePort = ReceivePort();
      final errorPort = ReceivePort();
      final exitPort = ReceivePort();

      await Isolate.spawn<BackupParams>(
        _performDriveBackup,
        BackupParams(
          sendPort: receivePort.sendPort,
          pathToZip: pathToZippedBackup,
          pathToBackupFile: pathToDatabaseCopy,
          includePhotos: true, // or based on user settings
          photosRootPath: await photosRootPath,
          authHeaders: (await GoogleDriveAuth.init()).authHeaders,
          progressStageStart: 3,
          progressStageEnd: 6,
        ),
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
      );

      final completer = Completer<void>();
      errorPort.listen((error) {
        Sentry.captureException(error);
        completer.completeError(error as Object);
      });
      exitPort.listen((message) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      receivePort.listen((message) {
        if (message is ProgressUpdate) {
          emitProgress(
            message.stageDescription,
            message.stageNo,
            message.stageCount,
          );
        }
      });

      await completer.future;
      receivePort.close();
      errorPort.close();
      exitPort.close();

      emitProgress('Backup completed', 6, 6);
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
  Future<void> _performDriveBackup(BackupParams params) async {
    await Sentry.init((options) {
      options
        ..dsn =
            'https://17bb41df4a5343530bfcb92553f4c5a7@o4507706035994624.ingest.us.sentry.io/4507706038157312'
        ..tracesSampleRate = 1.0;
    });

    final sendPort = params.sendPort;

    try {
      // Step 1: Zip the database.
      sendPort.send(
        ProgressUpdate(
          'Zipping database...',
          params.progressStageStart,
          params.progressStageEnd,
        ),
      );
      final encoder = ZipFileEncoder()..create(params.pathToZip);
      await encoder.addFile(File(params.pathToBackupFile));
      await encoder.close();

      // Step 2: Upload photos individually if requested.
      if (params.includePhotos) {
        sendPort.send(
          ProgressUpdate(
            'Uploading photos...',
            params.progressStageStart,
            params.progressStageEnd,
          ),
        );
        await uploadPhotosInBackup(params);
      }

      // Step 3: Upload the zip file (DB backup) to Google Drive.
      sendPort.send(
        ProgressUpdate(
          'Uploading backup file...',
          params.progressStageStart,
          params.progressStageEnd,
        ),
      );
      await uploadZipFile(params);

      sendPort.send(
        ProgressUpdate(
          'Backup completed',
          params.progressStageEnd,
          params.progressStageEnd,
        ),
      );
    } catch (e, st) {
      await Sentry.captureException(e, stackTrace: st);
      sendPort.send(
        ProgressUpdate(
          'Error during backup: $e',
          params.progressStageEnd,
          params.progressStageEnd,
        ),
      );
    }

    await Sentry.close();
    Isolate.exit();
  }

  @override
  Future<String> get photosRootPath => getPhotosRootPath();

  @override
  Future<String> get databasePath async =>
      join(await sql.getDatabasesPath(), 'handyman.db');

  @override
  Future<String> get backupLocation async =>
      'Google Drive: ${useDebugPath ? '/hmb/debug/backups/' : '/hmb/backups'}';

  @override
  set useDebugPath(bool bool) {}
}

import 'dart:async';
import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite_common/sqflite.dart' as sql;

import '../../../../../util/exceptions.dart';
import '../../../../../util/paths.dart'
    if (dart.library.ui) '../../../../util/paths_flutter.dart';
import '../backup_provider.dart';
import 'api.dart';
import 'zip_uploader.dart';

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
      final q = """
'$backupsFolderId' in parents and name='$fileName' and trashed=false""";

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

      final media = (await driveApi.files.get(
        backup.id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      )) as drive.Media;

      return saveStreamToFile(media.stream, createTempFile());
    } catch (e) {
      throw BackupException('Error downloading backup from Google Drive: $e');
    }
  }

  Future<File> saveStreamToFile(
      Stream<List<int>> stream, String filePath) async {
    // Open the file in write mode
    final file = File(filePath);
    final sink = file.openWrite();

    try {
      // Pipe the stream into the file sink
      await stream.pipe(sink);
    } finally {
      // Ensure the sink is closed to save the file
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
          .map((file) => Backup(
                id: file.id ?? '', // Include the file ID
                when: file.createdTime?.toLocal() ?? DateTime.now(),
                size: file.size ?? 'unknown',
                status: 'good',
                pathTo: file.name ?? 'Unknown',
                error: 'none',
              ))
          .toList();
    } catch (e) {
      throw BackupException('Error listing backups from Google Drive: $e');
    }
  }

  @override
  Future<BackupResult> store(
      {required String pathToDatabaseCopy,
      required String pathToZippedBackup,
      required int version}) async {
    try {
      emitProgress('Starting Google Drive upload', 5, 6);

      final uploader =
          ZipUploader(pathToZip: pathToZippedBackup, provider: this);
      await uploader.upload();

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

// Stream transformer to track progress
Stream<List<int>> trackProgress(Stream<List<int>> source, int totalLength,
    void Function(double) onProgress) {
  var bytesUploaded = 0;

  return source.transform(
    StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        bytesUploaded += data.length;
        final progress = (bytesUploaded / totalLength) * 100;
        onProgress(progress);
        sink.add(data); // Pass data along to the next consumer
      },
    ),
  );
}

// class _UploadComplete {
//   _UploadComplete(this.fileId);
//   final String fileId;
// }

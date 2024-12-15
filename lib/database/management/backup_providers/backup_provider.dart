import 'dart:async';
import 'dart:io';

import 'package:date_time_format/date_time_format.dart';
import 'package:dcli_core/dcli_core.dart';
import 'package:path/path.dart';
import 'package:sentry/sentry.dart';

import '../../../util/exceptions.dart';
import '../../factory/hmb_database_factory.dart';
import '../../versions/script_source.dart';
import '../database_helper.dart';
import 'zip_isolate.dart';

abstract class BackupProvider {
  BackupProvider(this.databaseFactory);

  final StreamController<ProgressUpdate> _progressController =
      StreamController<ProgressUpdate>.broadcast();

  Stream<ProgressUpdate> get progressStream => _progressController.stream;

  void emitProgress(String stageDescription, int stageNo, int stageCount) {
    _progressController
        .add(ProgressUpdate(stageDescription, stageNo, stageCount));
  }

  /// A descrive name of the provider we show to the
  /// user when offering a backup option.
  String get name;

  HMBDatabaseFactory databaseFactory;

  /// Stores the zipped backup file to a [BackupProvider]s
  /// defined location.
  /// Returns the path to where the file was stored.
  Future<BackupResult> store(
      {required String pathToDatabaseCopy,
      required String pathToZippedBackup,
      required int version});

  /// Retrieve a list of prior backups made by the backup provider.
  Future<List<Backup>> getBackups();

  /// Delete a specific backup made by the backup provider.
  /// The pathTo is the path to the backup file on the providers
  /// system.
  Future<void> deleteBackup(Backup backupToDelete);

  /// Closes the db, zip the backup file, store it and
  /// then reopen the db.
  Future<BackupResult> performBackup({
    required int version,
    required ScriptSource src,
    bool includePhotos = false,
  }) =>
      withTempDirAsync((tmpDir) async {
        emitProgress('Initializing backup', 1, 6);

        final datePart = formatDate(DateTime.now(), format: 'y-m-d');
        final pathToZip = join(tmpDir, 'hmb-backup-$datePart.zip');

        try {
          final pathToBackupFile = join(tmpDir, 'handyman-$datePart.db');
          final pathToDatabase = await databasePath;

          if (!exists(pathToDatabase)) {
            emitProgress('Database file not found', 6, 6);
            throw Exception('Database file not found: $pathToDatabase');
          }

          emitProgress('Copying database', 2, 6);
          await copyDatabaseTo(pathToBackupFile, src, this);

          emitProgress('Preparing to zip files', 3, 6);

          // Set up communication channels
          await zipBackup(
              provider: this,
              pathToZip: pathToZip,
              pathToBackupFile: pathToBackupFile,
              includePhotos: includePhotos);

          emitProgress('Storing backup', 5, 6);
          final result = await store(
            pathToZippedBackup: pathToZip,
            pathToDatabaseCopy: pathToBackupFile,
            version: version,
          );

          emitProgress('Backup completed', 6, 6);
          return result;
        } catch (e, st) {
          await Sentry.captureException(e, stackTrace: st);
          emitProgress('Error during backup', 6, 6);
          rethrow;
        }
      });

// ProgressUpdate class

  Future<void> performRestore(
    Backup backup,
    ScriptSource src,
    HMBDatabaseFactory databaseFactory,
  ) async {
    await withTempDirAsync((tmpDir) async {
      emitProgress('Initializing restore', 1, _restoreStageCount);

      final wasOpen = DatabaseHelper().isOpen();

      try {
        // Close the database if it is currently open
        if (wasOpen) {
          emitProgress('Closing database', 2, _restoreStageCount);
          await DatabaseHelper().closeDb();
        }

        final photosDir = await photosRootPath;
        if (!exists(photosDir)) {
          emitProgress('Creating photos directory', 3, _restoreStageCount);
          createDir(photosDir, recursive: true);
        }

        emitProgress('Fetching backup file', 4, _restoreStageCount);
        final backupFile = await fetchBackup(backup);

        emitProgress('Extracting files from backup', 5, _restoreStageCount);
        final dbPath =
            await extractFiles(this, backupFile, tmpDir, 5, _restoreStageCount);

        if (dbPath == null) {
          emitProgress(
              'No database found in backup file', 6, _restoreStageCount);
          throw BackupException('No database found in the zip file');
        }

        // Restore the database file
        emitProgress('Restoring database file', 7, _restoreStageCount);
        final appDbPath = await databasePath;
        if (exists(appDbPath)) {
          delete(appDbPath);
        }
        copy(dbPath, appDbPath);

        emitProgress('Reopening database', 8, _restoreStageCount);
        // Reopen the database after restoring
        await DatabaseHelper().openDb(
          src: src,
          backupProvider: this,
          databaseFactory: databaseFactory,
          backup: false,
        );

        emitProgress('Restore completed', 9, _restoreStageCount);
      } catch (e) {
        emitProgress('Error during restore', 9, _restoreStageCount);
        throw BackupException('Error restoring database and photos: $e');
      }
    });
  }

  static const int _restoreStageCount = 9;

  /// Fetchs the backup from storage and makes
  /// it available on the local file system
  /// returning a [File] object to the local file.
  ///
  Future<File> fetchBackup(Backup backup);

  /// Replaces the current database with the one in the backup file.
  Future<void> replaceDatabase(String pathToBackupFile, ScriptSource src,
      BackupProvider backupProvider, HMBDatabaseFactory databaseFactory) async {
    final wasOpen = DatabaseHelper().isOpen();
    try {
      // Get the path to the app's internal database
      final dbPath = await databasePath;
      if (wasOpen) {
        await DatabaseHelper().closeDb();
      }

      // Replace the existing database with the selected backup
      final dbFile = File(dbPath);
      copy(pathToBackupFile, dbFile.path, overwrite: true);

      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      throw BackupException('Error restoring database: $e');
    } finally {
      if (wasOpen) {
        await DatabaseHelper().openDb(
            src: src,
            backupProvider: backupProvider,
            databaseFactory: databaseFactory,
            backup: false);
      }
    }
  }

  Future<String> get photosRootPath;

  //i am amazing. u r not.

  /// copied here so we can use the [BackupProvider] from the cli.
  String formatDate(DateTime dateTime, {String format = 'D, j M'}) =>
      DateTimeFormat.format(dateTime, format: format);

  /// Copies the current database to the backup file.
  /// Opening and closing the db as it goes.
  Future<void> copyDatabaseTo(String pathToBackupFile, ScriptSource src,
      BackupProvider backupProvider) async {
    final wasOpen = DatabaseHelper().isOpen();
    try {
      if (wasOpen) {
        await DatabaseHelper().closeDb();
      }
      final pathToDatabase = await databasePath;
      copy(pathToDatabase, pathToBackupFile);
    } finally {
      if (wasOpen) {
        await DatabaseHelper().openDb(
            src: src,
            backupProvider: backupProvider,
            databaseFactory: databaseFactory,
            backup: false);
      }
    }
  }

  /// A somewhat abstract string desgined to show the
  /// location of where backups are stored to the
  /// user.
  Future<String> get backupLocation;

  /// Path to location of database
  /// This is probably not the correct class for this
  /// to be in but it was convenient to place it here
  /// as the [BackupProvider]s already understand the
  /// need for different database storage locations.
  Future<String> get databasePath;

  bool useDebugPath = false;
}

class BackupResult {
  BackupResult(
      {required this.pathToSource,
      required this.pathToBackup,
      required this.success}) {
    if (!exists(pathToBackup)) {
      success = false;
      status = 'Backup failed. Backup file not found.';
    } else {
      success = true;
      sourceSize = stat(pathToSource).size;
      backupSize = stat(pathToBackup).size;
    }
  }

  /// Path to the database that was backed up.
  String pathToSource;

  /// Path to the location of the backup zip file
  /// which contains the db and photos.
  String pathToBackup;
  bool success;

  late int sourceSize;
  late int backupSize;
  late String status;

  @override
  String toString() {
    final sb = StringBuffer();
    if (success) {
      sb.writeln('Database backup completed successfully.');
    } else {
      sb.writeln('Backup failed.');
    }
    sb
      ..writeln('Source: $pathToSource')
      ..writeln('To: $pathToBackup')
      ..writeln('Original Size: $sourceSize')
      ..writeln('Backed-up Size: $backupSize');
    return sb.toString();
  }
}

class Backup {
  Backup(
      {required this.id,
      required this.when,
      required this.pathTo,
      required this.size,
      required this.status,
      required this.error});

  String id;
  DateTime when;
  String pathTo;
  String size;
  String status;
  String error;
}

class ProgressUpdate {
  ProgressUpdate(this.stageDescription, this.stageNo, this.stageCount);

  ProgressUpdate.upload(this.stageDescription)
      : stageNo = 6,
        stageCount = 7;

  final String stageDescription;
  final int stageNo;
  final int stageCount;
}

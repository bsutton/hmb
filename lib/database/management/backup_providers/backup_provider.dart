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

import 'dart:async';
import 'dart:io';

import 'package:date_time_format/date_time_format.dart';
import 'package:dcli_core/dcli_core.dart';
import 'package:path/path.dart';
import 'package:sentry/sentry.dart';

import '../../../util/dart/exceptions.dart';
import '../../factory/hmb_database_factory.dart';
import '../../versions/script_source.dart';
import '../database_helper.dart';
import 'backup.dart';
import 'backup_encryption.dart';
import 'backup_history_store.dart';
import 'db_path.io.dart' if (dart.library.ui) 'db_path.dart';
import 'progress_update.dart';
import 'zip_isolate.dart';

const dbFileName = 'handyman.db';

abstract class BackupProvider {
  static const _restoreStageCount = 10;
  final _progressController = StreamController<ProgressUpdate>.broadcast();
  final HMBDatabaseFactory databaseFactory;

  // ignore: omit_obvious_property_types
  bool useDebugPath = false;

  BackupProvider(this.databaseFactory);

  /// A descrive name of the provider we show to the
  /// user when offering a backup option.
  String get name;

  Stream<ProgressUpdate> get progressStream => _progressController.stream;

  void emitProgress(String stageDescription, int stageNo, int stageCount) {
    _progressController.add(
      ProgressUpdate(stageDescription, stageNo, stageCount),
    );
  }

  /// Stores the zipped backup file to a [BackupProvider]s
  /// defined location.
  /// Returns the path to where the file was stored.
  Future<BackupResult> store({
    required String pathToDatabaseCopy,
    required String pathToZippedBackup,
    required int version,
  });

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
  }) => withTempDirAsync((tmpDir) async {
    emitProgress('Initializing backup', 1, 7);

    final datePart = formatDate(DateTime.now(), format: 'y-m-d');
    final pathToZip = join(tmpDir, 'hmb-backup-$datePart.zip');

    try {
      final pathToBackupFile = join(tmpDir, 'handyman-$datePart.db');
      final pathToDatabase = await databasePath;

      if (!exists(pathToDatabase)) {
        emitProgress('Database file not found', 7, 7);
        throw Exception('Database file not found: $pathToDatabase');
      }

      emitProgress('Copying database', 2, 7);
      await copyDatabaseTo(pathToBackupFile, src, this);

      emitProgress('Preparing to zip files', 3, 7);

      // Set up communication channels
      await zipBackup(
        provider: this,
        pathToZip: pathToZip,
        pathToBackupFile: pathToBackupFile,
      );

      // Encrypt the zip before uploading to cloud storage.
      // Falls back to unencrypted if secure storage is unavailable
      // (e.g., in test environments without platform channels).
      var pathToUpload = pathToZip;
      try {
        emitProgress('Encrypting backup', 5, 7);
        final pathToEncrypted = '$pathToZip.enc';
        await BackupEncryption.encryptFile(
          File(pathToZip),
          File(pathToEncrypted),
        ).timeout(const Duration(seconds: 10));
        pathToUpload = pathToEncrypted;
      } catch (e) {
        // Encryption unavailable or timed out — upload unencrypted zip
        emitProgress('Encryption skipped', 5, 7);
      }

      emitProgress('Storing backup', 6, 7);
      final result = await store(
        pathToZippedBackup: pathToUpload,
        pathToDatabaseCopy: pathToBackupFile,
        version: version,
      );
      await BackupHistoryStore.record(
        provider: name,
        operation: BackupHistoryStore.operationBackup,
        success: true,
      );

      emitProgress('Backup completed', 7, 7);
      return result;
    } catch (e, st) {
      await Sentry.captureException(e, stackTrace: st);
      await BackupHistoryStore.record(
        provider: name,
        operation: BackupHistoryStore.operationBackup,
        success: false,
        error: '$e',
      );
      emitProgress('Error during backup', 7, 7);
      rethrow;
    }
  });

  // ProgressUpdate class

  Future<void> performRestore(
    Backup backup,
    ScriptSource src,
    HMBDatabaseFactory databaseFactory,
  ) => withTempDirAsync((tmpDir) async {
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
      var backupFile = await fetchBackup(backup);

      // Decrypt if the backup is encrypted.
      // Falls back gracefully if secure storage is unavailable (tests)
      // or times out (no platform channel).
      try {
        final hasEncKey = await BackupEncryption.hasKey()
            .timeout(const Duration(seconds: 5), onTimeout: () => false);
        if (backupFile.path.endsWith('.enc') || hasEncKey) {
          emitProgress('Decrypting backup', 5, _restoreStageCount);
          final decryptedPath = join(tmpDir, 'decrypted-backup.zip');
          await BackupEncryption.decryptFile(
            backupFile,
            File(decryptedPath),
          );
          backupFile = File(decryptedPath);
        }
      } catch (_) {
        // Encryption unavailable or legacy unencrypted backup — proceed as-is
      }

      emitProgress('Extracting files from backup', 6, _restoreStageCount);
      final dbPath = await extractFiles(
        this,
        backupFile,
        tmpDir,
        5,
        _restoreStageCount,
      );

      if (dbPath == null) {
        emitProgress('No database found in backup file', 6, _restoreStageCount);
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
      await BackupHistoryStore.record(
        provider: name,
        operation: BackupHistoryStore.operationRestore,
        success: true,
      );
    } catch (e) {
      await BackupHistoryStore.record(
        provider: name,
        operation: BackupHistoryStore.operationRestore,
        success: false,
        error: '$e',
      );
      emitProgress('Error during restore', 9, _restoreStageCount);
      throw BackupException('Error restoring database and photos: $e');
    }
  });

  /// Fetchs the backup from storage and makes
  /// it available on the local file system
  /// returning a [File] object to the local file.
  ///
  Future<File> fetchBackup(Backup backup);

  /// Replaces the current database with the one in the backup file.
  Future<void> replaceDatabase(
    String pathToBackupFile,
    ScriptSource src,
    BackupProvider backupProvider,
    HMBDatabaseFactory databaseFactory,
  ) async {
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
    } catch (e) {
      throw BackupException('Error restoring database: $e');
    } finally {
      if (wasOpen) {
        await DatabaseHelper().openDb(
          src: src,
          backupProvider: backupProvider,
          databaseFactory: databaseFactory,
          backup: false,
        );
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
  Future<void> copyDatabaseTo(
    String pathToBackupFile,
    ScriptSource src,
    BackupProvider backupProvider,
  ) async {
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
          backup: false,
        );
      }
    }
  }

  Future<void> syncPhotos();

  /// A somewhat abstract string desgined to show the
  /// location of where backups are stored to the
  /// user.
  Future<String> get backupLocation;

  /// Path to location of database
  /// This is probably not the correct class for this
  /// to be in but it was convenient to place it here
  /// as the [BackupProvider]s already understand the
  /// need for different database storage locations.
  Future<String> get databasePath => pathToDatabase(dbFileName);
}

class BackupResult {
  bool success;

  /// Path to the database that was backed up.
  final String pathToSource;

  /// Path to the location of the backup zip file
  /// which contains the db and photos.
  final String pathToBackup;

  late int sourceSize;
  late int backupSize;
  late String status;

  BackupResult({
    required this.pathToSource,
    required this.pathToBackup,
    required this.success,
  }) {
    if (!exists(pathToBackup)) {
      success = false;
      status = 'Backup failed. Backup file not found.';
    } else {
      success = true;
      sourceSize = stat(pathToSource).size;
      backupSize = stat(pathToBackup).size;
    }
  }

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

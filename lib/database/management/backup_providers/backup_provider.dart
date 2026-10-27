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
import 'package:sqflite_common/sqlite_api.dart';

import '../../../util/dart/exceptions.dart';
import '../../factory/hmb_database_factory.dart';
import '../../versions/script_source.dart';
import '../database_helper.dart';
import 'backup.dart';
import 'backup_history_store.dart';
import 'db_path.io.dart' if (dart.library.ui) 'db_path.dart';
import 'progress_update.dart';
import 'zip_isolate.dart';

const dbFileName = 'handyman.db';

abstract class BackupProvider {
  static const _restoreStageCount = 9;
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
  }) => _withPrivateTempDir((tmpDir) async {
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
      if (File(pathToBackupFile).lengthSync() > maxRestoredDatabaseBytes) {
        throw BackupException('Database exceeds the supported backup size');
      }

      emitProgress('Preparing to zip files', 3, 6);

      // Set up communication channels
      await zipBackup(
        provider: this,
        pathToZip: pathToZip,
        pathToBackupFile: pathToBackupFile,
      );

      if (File(pathToZip).lengthSync() > maxBackupArchiveBytes) {
        throw BackupException('ZIP exceeds the supported backup size');
      }

      await _restrictFileToOwner(File(pathToZip));

      emitProgress('Storing backup', 5, 6);
      final result = await store(
        pathToZippedBackup: pathToZip,
        pathToDatabaseCopy: pathToBackupFile,
        version: version,
      );
      await BackupHistoryStore.record(
        provider: name,
        operation: BackupHistoryStore.operationBackup,
        success: true,
      );

      emitProgress('Backup completed', 6, 6);
      return result;
    } catch (e, st) {
      await Sentry.captureException(e, stackTrace: st);
      await BackupHistoryStore.record(
        provider: name,
        operation: BackupHistoryStore.operationBackup,
        success: false,
        error: '$e',
      );
      emitProgress('Error during backup', 6, 6);
      rethrow;
    }
  });

  // ProgressUpdate class

  Future<void> performRestore(
    Backup backup,
    ScriptSource src,
    HMBDatabaseFactory databaseFactory,
  ) => _withPrivateTempDir((tmpDir) async {
    emitProgress('Initializing restore', 1, _restoreStageCount);

    final wasOpen = DatabaseHelper().isOpen();

    try {
      emitProgress('Fetching backup file', 4, _restoreStageCount);
      final fetched = await fetchBackup(backup, join(tmpDir, 'download.zip'));
      final backupFile = await _snapshotBackup(
        fetched,
        join(tmpDir, 'snapshot.zip'),
      );

      emitProgress('Extracting files from backup', 5, _restoreStageCount);
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

      // Check SQLite structure while the original database remains open.
      await _validateRestoreDatabase(dbPath, databaseFactory);
      emitProgress('Restoring database file', 7, _restoreStageCount);
      await _installRestoredDatabase(
        dbPath,
        wasOpen: wasOpen,
        src: src,
        databaseFactory: databaseFactory,
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

  Future<void> _validateRestoreDatabase(
    String path,
    HMBDatabaseFactory factory,
  ) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    try {
      final rows = await db.rawQuery('PRAGMA integrity_check');
      if (rows.length != 1 || rows.single.values.single != 'ok') {
        throw BackupException('Backup database failed SQLite integrity check');
      }
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name IN ('customer', 'job', 'task')",
      );
      if (tables.length != 3) {
        throw BackupException('Backup database is not an HMB database');
      }
    } finally {
      await db.close();
    }
  }

  Future<void> _installRestoredDatabase(
    String stagedPath, {
    required bool wasOpen,
    required ScriptSource src,
    required HMBDatabaseFactory databaseFactory,
  }) async {
    final appDbPath = await databasePath;
    final restoreDir = await _createPrivateTempDirectory(
      dirname(appDbPath),
      '.hmb-restore-',
    );
    final candidate = File(join(restoreDir.path, 'candidate.db'));
    const suffixes = ['', '-wal', '-shm', '-journal'];
    final saved = <String>[];
    var cleanup = true;
    var candidateInstalled = false;
    try {
      await File(stagedPath).copy(candidate.path);
      await _restrictFileToOwner(candidate);
      if (wasOpen) {
        emitProgress('Closing database', 7, _restoreStageCount);
        await DatabaseHelper().closeDb();
      }
      for (final suffix in suffixes) {
        final current = File('$appDbPath$suffix');
        if (current.existsSync()) {
          await current.rename(join(restoreDir.path, 'previous$suffix'));
          saved.add(suffix);
        }
      }
      await candidate.rename(appDbPath);
      candidateInstalled = true;
      emitProgress('Reopening database', 8, _restoreStageCount);
      await DatabaseHelper().openDb(
        src: src,
        backupProvider: this,
        databaseFactory: databaseFactory,
        backup: false,
      );
    } catch (error, stack) {
      try {
        if (candidateInstalled || saved.isNotEmpty) {
          if (DatabaseHelper().isOpen()) {
            await DatabaseHelper().closeDb();
          }
          if (candidateInstalled) {
            for (final suffix in suffixes) {
              final current = File('$appDbPath$suffix');
              if (current.existsSync()) {
                await current.delete();
              }
            }
          }
          for (final suffix in saved) {
            await File(
              join(restoreDir.path, 'previous$suffix'),
            ).rename('$appDbPath$suffix');
          }
        }
        if (wasOpen &&
            !DatabaseHelper().isOpen() &&
            File(appDbPath).existsSync()) {
          await DatabaseHelper().openDb(
            src: src,
            backupProvider: this,
            databaseFactory: databaseFactory,
            backup: false,
          );
        }
      } catch (rollbackError) {
        // Retain the private rollback directory for manual recovery.
        cleanup = false;
        throw BackupException(
          'Restore failed and rollback also failed; previous database is in '
          '${restoreDir.path}: $rollbackError',
        );
      }
      Error.throwWithStackTrace(error, stack);
    } finally {
      if (cleanup) {
        await restoreDir.delete(recursive: true);
      }
    }
  }

  /// Fetchs the backup from storage and makes
  /// it available on the local file system
  /// returning a [File] object to the local file.
  ///
  Future<File> fetchBackup(Backup backup, String privateDestination);

  /// Ensure a backup remains owner-readable after a cross-volume copy.
  Future<void> secureStoredBackup(String path) =>
      _restrictFileToOwner(File(path));

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

Future<T> _withPrivateTempDir<T>(Future<T> Function(String) action) async {
  final directory = await _createPrivateTempDirectory(
    Directory.systemTemp.path,
    'hmb-backup-',
  );
  try {
    return await action(directory.path);
  } finally {
    await directory.delete(recursive: true);
  }
}

Future<Directory> _createPrivateTempDirectory(
  String parent,
  String prefix,
) async {
  if (!Platform.isLinux && !Platform.isMacOS) {
    // Mobile app sandboxes and Windows profile ACLs protect these roots.
    return await Directory(parent).createTemp(prefix);
  }
  // Dart Directory.createTemp and DCLI createTempDir both honor a permissive
  // umask on POSIX. mktemp creates the directory atomically with mode 0700.
  const mktemp = '/usr/bin/mktemp';
  final result = await Process.run(mktemp, [
    '-d',
    join(parent, '${prefix}XXXXXX'),
  ]);
  if (result.exitCode != 0) {
    throw const FileSystemException(
      'Unable to create private backup directory',
    );
  }
  final path = (result.stdout as String).trim();
  if (!isWithin(absolute(parent), absolute(path))) {
    throw FileSystemException('Invalid private backup directory', path);
  }
  return Directory(path);
}

Future<void> _restrictFileToOwner(File file) async {
  if (!Platform.isLinux && !Platform.isMacOS) {
    return;
  }
  final chmod = Platform.isMacOS ? '/bin/chmod' : '/usr/bin/chmod';
  final result = await Process.run(chmod, ['600', file.path]);
  if (result.exitCode != 0) {
    throw FileSystemException('Unable to secure backup file', file.path);
  }
}

Future<File> _snapshotBackup(File source, String destination) async {
  final snapshot = File(destination);
  final sink = snapshot.openWrite();
  var copied = 0;
  var complete = false;
  try {
    await for (final chunk in source.openRead()) {
      copied += chunk.length;
      if (copied > maxBackupArchiveBytes) {
        throw BackupException('Backup ZIP exceeds the supported size');
      }
      sink.add(chunk);
    }
    await sink.flush();
    complete = true;
    return snapshot;
  } finally {
    await sink.close();
    if (!complete && snapshot.existsSync()) {
      await snapshot.delete();
    }
  }
}

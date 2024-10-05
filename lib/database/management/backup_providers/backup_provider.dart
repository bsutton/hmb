import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:date_time_format/date_time_format.dart';
import 'package:dcli_core/dcli_core.dart';
import 'package:path/path.dart';

import '../../../util/exceptions.dart';
import '../../factory/hmb_database_factory.dart';
import '../../versions/script_source.dart';
import '../database_helper.dart';

abstract class BackupProvider {
  BackupProvider(this.databaseFactory);

  HMBDatabaseFactory databaseFactory;

  /// Returns tthe path to where the file was stored.
  // TODO(bsutton): this should be a uri
  Future<BackupResult> store(
      {required String pathToDatabase,
      required String pathToZippedBackup,
      required int version});

  /// Retrieve a list of prior backups made by the backup provider.
  Future<List<String>> getBackups();

  /// Retrieve a specific backup made by the backup provider.
  Future<Backup> getBackup(String pathTo);

  /// Delete a specific backup made by the backup provider.
  /// The pathTo is the path to the backup file on the providers
  /// system.
  Future<void> deleteBackup(Backup backupToDelete);

  /// Closes the db, zip the backup file, store it and
  /// then reopen the db.
  Future<BackupResult> performBackup(
      {required int version, required ScriptSource src}) async {
    final encoder = ZipFileEncoder();

    return withTempDirAsync((tmpDir) async {
      final datePart = formatDate(DateTime.now(), format: 'y-m-d');
      final pathToZip = join(tmpDir, 'hmb-backup-$datePart.zip');
      encoder.create(pathToZip);

      final pathToBackupFile = join(tmpDir, 'handyman-$datePart.db');

      await copyDatabaseTo(pathToBackupFile, src, this);
      await encoder.addFile(File(pathToBackupFile));
      await encoder.close();

      //after that some of code for making the zip files
      return store(
          pathToZippedBackup: pathToZip,
          pathToDatabase: pathToBackupFile,
          version: version);
    });
    //i am amazing. u r not.
  }

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
        if (wasOpen) {
          await DatabaseHelper().closeDb();
        }
      }
      final pathToDatabase = await DatabaseHelper().pathToDatabase();
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

  Future<void> restoreDatabase(String pathToRestoreDatabase,
      BackupProvider backupProvider, HMBDatabaseFactory databaseFactory);

  /// Replaces the current database with the one in the backup file.
  Future<void> replaceDatabase(String pathToBackupFile, ScriptSource src,
      BackupProvider backupProvider, HMBDatabaseFactory databaseFactory) async {
    final wasOpen = DatabaseHelper().isOpen();
    try {
      // Get the path to the app's internal database
      final dbPath = await DatabaseHelper().pathToDatabase();
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
  String pathToSource;
  String pathToBackup;
  bool success;

  late int sourceSize;
  late int backupSize;
  late String status;

  @override
  String toString() {
    final sb = StringBuffer();
    if (success) {
      sb.write('Database backup completed successfully.');
    }
    sb
      ..write('Source: $pathToSource')
      ..write('To: $pathToBackup')
      ..write('Original Size: $sourceSize')
      ..write('Backuped Size: $backupSize');
    return sb.toString();
  }
}

class Backup {
  Backup(
      {required this.when,
      required this.pathTo,
      required this.size,
      required this.status,
      required this.error});
  DateTime when;
  String pathTo;
  String size;
  String status;
  String error;
}

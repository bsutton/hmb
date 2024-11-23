import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:date_time_format/date_time_format.dart';
import 'package:dcli_core/dcli_core.dart';
import 'package:path/path.dart';

import '../../../util/exceptions.dart';
import '../../../util/sentry_noop.dart'
    if (dart.library.ui) 'package:sentry_flutter/sentry_flutter.dart';
import '../../factory/hmb_database_factory.dart';
import '../../versions/script_source.dart';
import '../database_helper.dart';

abstract class BackupProvider {
  BackupProvider(this.databaseFactory);

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
  Future<BackupResult> performBackup(
          {required int version,
          required ScriptSource src,
          bool includePhotos = false}) =>
      withTempDirAsync((tmpDir) async {
        final datePart = formatDate(DateTime.now(), format: 'y-m-d');
        final pathToZip = join(tmpDir, 'hmb-backup-$datePart.zip');
        final encoder = ZipFileEncoder();
        var open = false;
        try {
          final pathToBackupFile = join(tmpDir, 'handyman-$datePart.db');
          final pathToDatabase = await databasePath;

          if (!exists(pathToDatabase)) {
            print('''
Database file not found at $pathToDatabase. No backup performed.''');
            return BackupResult(
                pathToBackup: pathToBackupFile,
                pathToSource: '',
                success: false);
          }

          var photoFilePaths = <String>[];
          if (includePhotos) {
            photoFilePaths = await getAllPhotoPaths();
          }

          await copyDatabaseTo(pathToBackupFile, src, this);

          encoder.create(pathToZip);
          open = true;
          await encoder.addFile(File(pathToBackupFile));

          // Now, if includePhotos is true, add the photo files to the zip
          if (includePhotos) {
            for (final relativePhotoPath in photoFilePaths) {
              final fullPathToPhoto =
                  join(await photosRootPath, relativePhotoPath);
              if (exists(fullPathToPhoto)) {
                final zipPath = join('photos', relativePhotoPath);
                await encoder.addFile(File(fullPathToPhoto), zipPath);
              } else {
                print('Photo file not found: $fullPathToPhoto');
              }
            }
          }

          encoder.closeSync();
          open = false;

          //after that some of code for making the zip files
          return store(
              pathToZippedBackup: pathToZip,
              pathToDatabaseCopy: pathToBackupFile,
              version: version);
        } catch (e, st) {
          if (Platform.isAndroid || Platform.isIOS) {
            await Sentry.captureException(e, stackTrace: st);
          }
          if (open) {
            encoder.closeSync();
          }
          rethrow;
        }
      });

  Future<void> performRestore(Backup backup, ScriptSource src,
      HMBDatabaseFactory databaseFactory) async {
    await withTempDirAsync((tmpDir) async {
      final wasOpen = DatabaseHelper().isOpen();

      try {
        // Close the database if it is currently open
        if (wasOpen) {
          await DatabaseHelper().closeDb();
        }

        final photosDir = await photosRootPath;
        if (!exists(photosDir)) {
          createDir(photosDir, recursive: true);
        }
        final backupFile = await fetchBackup(backup);

        final dbPath = await extractFiles(backupFile, tmpDir);

        if (dbPath == null) {
          throw BackupException('No database found in the zip file');
        }

        // Restore the database file
        final appDbPath = await databasePath;
        if (exists(appDbPath)) {
          delete(appDbPath);
        }
        copy(dbPath, appDbPath);

        // Reopen the database after restoring
        await DatabaseHelper().openDb(
            src: src,
            backupProvider: this,
            databaseFactory: databaseFactory,
            backup: false);
      } catch (e) {
        throw BackupException('Error restoring database and photos: $e');
      }
    });
  }

  /// Fetchs the backup from storage and makes
  /// it available on the local file system
  /// returning a [File] object to the local file.
  ///
  Future<File> fetchBackup(Backup backup);

  /// We can't use DaoPhoto as it uses June which is a flutter component
  /// and we need this to work from the cli.
  Future<List<String>> getAllPhotoPaths() async {
    final db = DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps =
        await db.query('photo', columns: ['filePath']);
    return maps.map((map) => map['filePath'] as String).toList();
  }

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

  /// All photos are stored under this path in the zip file
  final zipPhotoRoot = 'photos/';

  Future<String> get photosRootPath;

  Future<String?> extractFiles(File backupFile, String tmpDir) async {
    final encoder = ZipDecoder();
    String? dbPath;
    // Extract the ZIP file contents to a temporary directory
    final archive = encoder.decodeBuffer(InputFileStream(backupFile.path));

    for (final file in archive) {
      final filename = file.name;
      final filePath = join(tmpDir, filename);

      if (file.isFile) {
        // If the file is the database extact it
        // to a temp dir and return the path.
        if (filename.endsWith('.db')) {
          dbPath = filePath;
          _expandZippedFileToDisk(filePath, file);
        }

        // Write files to the temporary directory
        if (filename.startsWith(zipPhotoRoot)) {
          final parts = split(filename);
          final photoDestPath =
              joinAll([await photosRootPath, ...parts.sublist(1)]);

          _expandZippedFileToDisk(photoDestPath, file);
        }
      }
    }

    return dbPath;
  }

  void _expandZippedFileToDisk(String photoDestPath, ArchiveFile file) {
    File(photoDestPath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(file.content as List<int>);
  }

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

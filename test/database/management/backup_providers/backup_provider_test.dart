import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/flutter_database_factory.dart';
import 'package:hmb/database/factory/hmb_database_factory.dart';
import 'package:hmb/database/management/backup_providers/backup_provider.dart';
import 'package:hmb/database/management/database_helper.dart';
import 'package:hmb/database/versions/project_script_source.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../db_utility_test.dart';
import 'test_backup_provider.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  sqfliteFfiInit();

  group('Database Backup and Restore', () {
    final HMBDatabaseFactory databaseFactory = FlutterDatabaseFactory();
    late final BackupProvider backupProvider =
        TestBackupProvider(databaseFactory, testDbPath);

    setUp(() async {
      // Insert mock data into the test database
      final db = testDb!;
      await db.insert('photo', {
        'id': 1,
        'parentId': 1,
        'parentType': 'task',
        'filePath': 'test_photo.jpg',
        'comment': 'Test photo comment',
        'created_date': DateTime.now().toIso8601String(),
        'modified_date': DateTime.now().toIso8601String(),
      });

      // Create a mock photo file
      final photoDir = await backupProvider.photosRootPath;

      if (!exists(photoDir)) {
        createDir(photoDir, recursive: true);
      }
      final photoFile = File(p.join(photoDir, 'test_photo.jpg'));
      await photoFile.writeAsString('This is a test photo');
    });

    test('Backup and restore database and photos', () async {
      // Perform a backup, including photos
      final backupResult = await backupProvider.performBackup(
        version: 1,
        src: ProjectScriptSource(),
        includePhotos: true,
      );

      // Verify the backup was created successfully
      expect(backupResult.success, isTrue);
      expect(File(backupResult.pathToBackup).existsSync(), isTrue);

       await DatabaseHelper().closeDb();

      // Delete the original database and photo for testing restore
      final dbPath = await backupProvider.databasePath;
      if (File(dbPath).existsSync()) {
        File(dbPath).deleteSync();
      }
      final photoFile =
          File(p.join(await backupProvider.photosRootPath, 'test_photo.jpg'));
      if (photoFile.existsSync()) {
        photoFile.deleteSync();
      }

      // Perform restore from the backup file
      await backupProvider.performRestore(
        backupResult.pathToBackup,
        ProjectScriptSource(),
        databaseFactory,
      );

      // Reopen the database and verify the restored data
      await DatabaseHelper().openDb(
        src: ProjectScriptSource(),
        backupProvider: backupProvider,
        databaseFactory: databaseFactory,
        backup: false,
      );

      // Verify database restoration
      final restoredDb = DatabaseHelper().database;
      final restoredPhoto =
          await restoredDb.query('photo', where: 'id = ?', whereArgs: [1]);
      expect(restoredPhoto.isNotEmpty, isTrue);
      expect(restoredPhoto.first['filePath'], 'test_photo.jpg');

      // Verify photo restoration
      final restoredPhotoFile =
          File(p.join(await backupProvider.photosRootPath, 'test_photo.jpg'));
      expect(restoredPhotoFile.existsSync(), isTrue);
      expect(await restoredPhotoFile.readAsString(), 'This is a test photo');
    });
  });
}
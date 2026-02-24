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

import 'dart:io';

import 'package:dcli/dcli.dart' hide delete;
import 'package:dcli_core/dcli_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/flutter_database_factory.dart';
import 'package:hmb/database/factory/hmb_database_factory.dart';
import 'package:hmb/database/management/backup_providers/backup.dart';
import 'package:hmb/database/management/backup_providers/backup_history_store.dart';
import 'package:hmb/database/management/backup_providers/backup_provider.dart';
import 'package:hmb/database/management/database_helper.dart';
import 'package:hmb/database/versions/implementations/project_script_source.dart';
import 'package:path/path.dart' hide equals;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../db_utility_test_helper.dart';
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
    late final BackupProvider backupProvider = TestBackupProvider(
      databaseFactory,
      testDbPath,
    );

    setUp(() async {
      // Insert mock data into the test database
      final db = testDb!;
      await db.insert('photo', {
        'id': 1,
        'parentId': 1,
        'parentType': 'task',
        'filename': 'test_photo.jpg',
        'comment': 'Test photo comment',
        'created_date': DateTime.now().toIso8601String(),
        'modified_date': DateTime.now().toIso8601String(),
      });

      // Create a mock photo file
      final photoDir = await backupProvider.photosRootPath;

      if (!exists(photoDir)) {
        createDir(photoDir, recursive: true);
      }
      final photoFile = File(join(photoDir, 'test_photo.jpg'));
      await photoFile.writeAsString('This is a test photo');
    });

    test('Backup and restore database and photos', () async {
      // Perform a backup, including photos
      final backupResult = await backupProvider.performBackup(
        version: 1,
        src: ProjectScriptSource(),
      );

      // Verify the backup was created successfully
      expect(backupResult.success, isTrue);
      expect(File(backupResult.pathToBackup).existsSync(), isTrue);
      expect(await BackupHistoryStore.latestSuccessfulBackup(), isNotNull);

      await DatabaseHelper().closeDb();

      // Delete the original database and photo for testing restore
      final dbPath = await backupProvider.databasePath;
      if (File(dbPath).existsSync()) {
        File(dbPath).deleteSync();
      }
      final photoFile = File(
        join(await backupProvider.photosRootPath, 'test_photo.jpg'),
      );
      if (photoFile.existsSync()) {
        photoFile.deleteSync();
      }

      // Perform restore from the backup file
      await backupProvider.performRestore(
        Backup(
          id: 'not used',
          when: DateTime.now(),
          pathTo: backupResult.pathToBackup,
          size: 'unknown',
          status: 'good',
          error: 'none',
        ),
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
      final restoredPhoto = await restoredDb.query(
        'photo',
        where: 'id = ?',
        whereArgs: [1],
      );
      expect(restoredPhoto.isNotEmpty, isTrue);
      expect(restoredPhoto.first['filename'], 'test_photo.jpg');

      final restoreRuns = await restoredDb.query(
        'backup_history',
        where: 'operation = ? AND success = 1',
        whereArgs: [BackupHistoryStore.operationRestore],
      );
      expect(restoreRuns.isNotEmpty, isTrue);

      // Photos are no longer stored in backup zips (synced separately).
    });
  });

  group('Backup file naming', () {
    test('store appends incremental suffixes without stacking', () async {
      final provider = TestBackupProvider(FlutterDatabaseFactory(), testDbPath);
      final backupsDir = join(DartProject.self.pathToProjectRoot, 'backups');
      if (!exists(backupsDir)) {
        createDir(backupsDir, recursive: true);
      }

      const baseName = 'hmb-backup-26-01-31.zip';
      final basePath = join(backupsDir, baseName);
      final first = join(backupsDir, 'hmb-backup-26-01-31.1.zip');
      final second = join(backupsDir, 'hmb-backup-26-01-31.2.zip');

      final created = <String>[];
      for (final path in [basePath, first, second]) {
        File(path).writeAsStringSync('x');
        created.add(path);
      }

      final tmpZip = join(createTempDir(), baseName);
      File(tmpZip).writeAsStringSync('zip');

      final result = await provider.store(
        pathToDatabaseCopy: testDbPath,
        pathToZippedBackup: tmpZip,
        version: 1,
      );

      created.add(result.pathToBackup);
      expect(
        basename(result.pathToBackup),
        equals('hmb-backup-26-01-31.3.zip'),
      );

      for (final path in created) {
        if (exists(path)) {
          delete(path);
        }
      }
    });
  });
}

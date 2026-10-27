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

@Tags(['flutter'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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
    late BackupProvider backupProvider;

    setUp(() async {
      backupProvider = TestBackupProvider(
        databaseFactory,
        testDbPath,
        backupDirectory: join(dirname(testDbPath), 'backups'),
        photosDirectory: join(dirname(testDbPath), 'photos'),
      );
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

    test('rejected backup leaves the existing database open', () async {
      final backup = File(join(dirname(testDbPath), 'invalid-restore.zip'))
        ..writeAsBytesSync(
          ZipEncoder().encode(
            Archive()..addFile(ArchiveFile.bytes('photos/handyman.db', [1])),
          ),
        );
      try {
        expect(DatabaseHelper().isOpen(), isTrue);
        await expectLater(
          backupProvider.performRestore(
            Backup(
              id: 'invalid',
              when: DateTime.now(),
              pathTo: backup.path,
              size: 'unknown',
              status: 'invalid',
              error: '',
            ),
            ProjectScriptSource(),
            databaseFactory,
          ),
          throwsException,
        );
        expect(DatabaseHelper().isOpen(), isTrue);
        expect(
          await DatabaseHelper().database.query('photo', where: 'id = 1'),
          isNotEmpty,
        );
      } finally {
        backup.deleteSync();
      }
    });

    test('invalid SQLite backup cannot replace the live database', () async {
      final backup = File(join(dirname(testDbPath), 'invalid-database.zip'))
        ..writeAsBytesSync(
          ZipEncoder().encode(
            Archive()..addFile(
              ArchiveFile.bytes(
                'handyman.db',
                utf8.encode('not a SQLite database'),
              ),
            ),
          ),
        );
      try {
        expect(DatabaseHelper().isOpen(), isTrue);
        await expectLater(
          backupProvider.performRestore(
            Backup(
              id: 'invalid-db',
              when: DateTime.now(),
              pathTo: backup.path,
              size: 'unknown',
              status: 'invalid',
              error: '',
            ),
            ProjectScriptSource(),
            databaseFactory,
          ),
          throwsException,
        );
        expect(DatabaseHelper().isOpen(), isTrue);
        expect(
          await DatabaseHelper().database.query('photo', where: 'id = 1'),
          isNotEmpty,
        );
      } finally {
        backup.deleteSync();
      }
    });

    test('unrelated valid SQLite backup cannot replace HMB data', () async {
      final unrelated = File(join(dirname(testDbPath), 'unrelated.db'));
      final other = await databaseFactory.openDatabase(
        unrelated.path,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await other.execute('CREATE TABLE unrelated (id INTEGER PRIMARY KEY)');
      await other.close();
      final backup = File(join(dirname(testDbPath), 'unrelated.zip'))
        ..writeAsBytesSync(
          ZipEncoder().encode(
            Archive()..addFile(
              ArchiveFile.bytes('handyman.db', unrelated.readAsBytesSync()),
            ),
          ),
        );
      try {
        await expectLater(
          backupProvider.performRestore(
            Backup(
              id: 'unrelated',
              when: DateTime.now(),
              pathTo: backup.path,
              size: 'unknown',
              status: 'invalid',
              error: '',
            ),
            ProjectScriptSource(),
            databaseFactory,
          ),
          throwsException,
        );
        expect(DatabaseHelper().isOpen(), isTrue);
        expect(
          await DatabaseHelper().database.query('photo', where: 'id = 1'),
          isNotEmpty,
        );
      } finally {
        backup.deleteSync();
        unrelated.deleteSync();
      }
    });

    test('failed reopen rolls back the original database', () async {
      final backupResult = await backupProvider.performBackup(
        version: 1,
        src: ProjectScriptSource(),
      );
      await DatabaseHelper().database.update('photo', {
        'comment': 'live-only-after-backup',
      }, where: 'id = 1');
      final failingFactory = _FailOnceFactory(databaseFactory, testDbPath);
      await expectLater(
        backupProvider.performRestore(
          Backup(
            id: 'valid',
            when: DateTime.now(),
            pathTo: backupResult.pathToBackup,
            size: 'unknown',
            status: 'good',
            error: '',
          ),
          ProjectScriptSource(),
          failingFactory,
        ),
        throwsException,
      );
      expect(failingFactory.failed, isTrue);
      expect(DatabaseHelper().isOpen(), isTrue);
      final livePhoto = await DatabaseHelper().database.query(
        'photo',
        where: 'id = 1',
      );
      expect(livePhoto.single['comment'], 'live-only-after-backup');
    });

    test('backup staging and stored ZIP are private on Linux', () async {
      if (!Platform.isLinux) {
        return;
      }
      final inspecting = _InspectingBackupProvider(
        databaseFactory,
        testDbPath,
        backupDirectory: join(dirname(testDbPath), 'private-backups'),
      );
      final result = await inspecting.performBackup(
        version: 1,
        src: ProjectScriptSource(),
      );
      expect(inspecting.stagingMode, '700');
      final stored = await Process.run('stat', [
        '-c',
        '%a',
        result.pathToBackup,
      ]);
      expect(stored.stdout.toString().trim(), '600');
    });
  });

  group('Backup file naming', () {
    test('store appends incremental suffixes without stacking', () async {
      final backupsDir = join(dirname(testDbPath), 'backups');
      final provider = TestBackupProvider(
        FlutterDatabaseFactory(),
        testDbPath,
        backupDirectory: backupsDir,
      );
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

class _FailOnceFactory implements HMBDatabaseFactory {
  final HMBDatabaseFactory delegate;
  final String livePath;
  var failed = false;

  _FailOnceFactory(this.delegate, this.livePath);

  @override
  Future<Database> openDatabase(
    String path, {
    required OpenDatabaseOptions options,
  }) async {
    if (path == livePath && !failed) {
      failed = true;
      final candidate = await delegate.openDatabase(path, options: options);
      await candidate.rawQuery('PRAGMA user_version');
      await candidate.close();
      throw StateError('Simulated reopen failure');
    }
    return await delegate.openDatabase(path, options: options);
  }
}

class _InspectingBackupProvider extends TestBackupProvider {
  String? stagingMode;

  _InspectingBackupProvider(
    super.databaseFactory,
    super.pathToDatabase, {
    super.backupDirectory,
  });

  @override
  Future<BackupResult> store({
    required String pathToDatabaseCopy,
    required String pathToZippedBackup,
    required int version,
  }) async {
    final mode = await Process.run('stat', [
      '-c',
      '%a',
      dirname(pathToZippedBackup),
    ]);
    stagingMode = mode.stdout.toString().trim();
    return await super.store(
      pathToDatabaseCopy: pathToDatabaseCopy,
      pathToZippedBackup: pathToZippedBackup,
      version: version,
    );
  }
}

@Tags(['flutter'])
library;

import 'package:dcli/dcli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/database/versions/script_source.dart';
import 'package:path/path.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../management/backup_providers/test_backup_provider.dart';

void main() {
  test('upgrade resumes from the highest completed HMB migration', () async {
    final dbPath = join(createTempDir(), 'upgrade_resume_version.db');
    final db = await CliDatabaseFactory().openDatabase(
      dbPath,
      options: OpenDatabaseOptions(),
    );

    try {
      expect(await getUpgradeResumeVersion(db, 189), 189);

      await db.execute('''
CREATE TABLE version (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  db_version INTEGER NOT NULL
)
''');
      await db.insert('version', {'db_version': 190});
      await db.insert('version', {'db_version': 208});

      expect(await getUpgradeResumeVersion(db, 189), 208);
      expect(await getUpgradeResumeVersion(db, 209), 209);
    } finally {
      await db.close();
      delete(dbPath);
    }
  });

  test('upgrade runs every missing migration and safely resumes', () async {
    final dbPath = join(createTempDir(), 'upgrade_all_versions.db');
    final factory = CliDatabaseFactory();
    final db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(),
    );
    final source = _TestScriptSource({
      101: 'CREATE TABLE migration_101 (id INTEGER PRIMARY KEY)',
      102: 'CREATE TABLE migration_102 (id INTEGER PRIMARY KEY)',
      103: 'CREATE TABLE migration_103 (id INTEGER PRIMARY KEY)',
    });

    try {
      await db.execute('''
CREATE TABLE version (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  db_version INTEGER NOT NULL,
  code_version TEXT NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
)
''');
      await db.insert('version', {
        'db_version': 100,
        'code_version': 'test',
        'created_date': '2026-08-14T00:00:00.000',
        'modified_date': '2026-08-14T00:00:00.000',
      });

      await upgradeDb(
        db: db,
        oldVersion: 100,
        newVersion: 103,
        backup: false,
        src: source,
        backupProvider: TestBackupProvider(factory, dbPath),
      );

      expect(await _tableExists(db, 'migration_101'), isTrue);
      expect(await _tableExists(db, 'migration_102'), isTrue);
      expect(await _tableExists(db, 'migration_103'), isTrue);

      source.scripts[104] =
          'CREATE TABLE migration_104 (id INTEGER PRIMARY KEY)';
      await upgradeDb(
        db: db,
        oldVersion: 100,
        newVersion: 104,
        backup: false,
        src: source,
        backupProvider: TestBackupProvider(factory, dbPath),
      );

      expect(await _tableExists(db, 'migration_104'), isTrue);
      final versions = await db.query(
        'version',
        columns: const ['db_version'],
        orderBy: 'db_version',
      );
      expect(versions.map((row) => row['db_version']), [
        100,
        101,
        102,
        103,
        104,
      ]);
    } finally {
      await db.close();
      delete(dbPath);
    }
  });
}

Future<bool> _tableExists(Database db, String table) async => (await db.query(
  'sqlite_master',
  where: "type = 'table' AND name = ?",
  whereArgs: [table],
)).isNotEmpty;

class _TestScriptSource implements ScriptSource {
  final Map<int, String> scripts;

  _TestScriptSource(this.scripts);

  @override
  Future<String> loadSQL(String pathToScript) async =>
      scripts[_version(pathToScript)]!;

  @override
  Future<List<String>> upgradeScripts() async =>
      scripts.keys.map((version) => 'v$version.sql').toList();

  int _version(String path) =>
      int.parse(RegExp(r'v(\d+)\.sql').firstMatch(path)!.group(1)!);
}

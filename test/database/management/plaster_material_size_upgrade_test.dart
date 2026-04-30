import 'package:dcli/dcli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/database/versions/implementations/project_script_source.dart';
import 'package:path/path.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test(
    'v164 migrates plaster material sizes from project to supplier',
    () async {
      final dbPath = join(createTempDir(), 'plaster_material_v163.db');
      final db = await CliDatabaseFactory().openDatabase(
        dbPath,
        options: OpenDatabaseOptions(),
      );

      try {
        final source = ProjectScriptSource();
        for (final script in [
          'assets/sql/upgrade_scripts/v163.sql',
          'assets/sql/upgrade_scripts/v164.sql',
        ]) {
          if (script.endsWith('v163.sql')) {
            final sql = await source.loadSQL(script);
            final statements = await parseSqlFile(sql);
            for (final statement in statements) {
              await db.execute(statement);
            }

            await db.execute('''
CREATE TABLE job (
  id INTEGER PRIMARY KEY AUTOINCREMENT
)
''');
            await db.insert('job', {'id': 1});
            await db.execute('''
CREATE TABLE supplier (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  businessNumber TEXT,
  description TEXT,
  bsb TEXT,
  accountNumber TEXT,
  service TEXT,
  createdDate TEXT,
  modifiedDate TEXT
)
''');
            await db.insert('supplier', {
              'id': 7,
              'name': 'Plaster Supplier',
              'businessNumber': '',
              'description': '',
              'bsb': '',
              'accountNumber': '',
              'service': '',
              'createdDate': '2026-03-24T00:00:00.000',
              'modifiedDate': '2026-03-24T00:00:00.000',
            });
            await db.insert('plaster_project', {
              'id': 3,
              'name': 'Project',
              'job_id': 1,
              'task_id': null,
              'supplier_id': 7,
              'waste_percent': 15,
              'created_date': '2026-03-24T00:00:00.000',
              'modified_date': '2026-03-24T00:00:00.000',
            });
            await db.insert('plaster_material_size', {
              'project_id': 3,
              'name': '1200 x 2400',
              'unit_system': 'metric',
              'width': 12000,
              'height': 24000,
              'created_date': '2026-03-24T00:00:00.000',
              'modified_date': '2026-03-24T00:00:00.000',
            });
          } else {
            final sql = await source.loadSQL(script);
            final statements = await parseSqlFile(sql);
            for (final statement in statements) {
              await db.execute(statement);
            }
          }
        }

        final columns = await db.rawQuery(
          'PRAGMA table_info(plaster_material_size)',
        );
        final names = {
          for (final row in columns) row['name'] as String? ?? '': true,
        };
        final rows = await db.query('plaster_material_size');

        expect(names.containsKey('supplier_id'), isTrue);
        expect(names.containsKey('project_id'), isFalse);
        expect(rows, hasLength(1));
        expect(rows.single['supplier_id'], 7);
        expect(rows.single['name'], '1200 x 2400');
      } finally {
        await db.close();
        delete(dbPath);
      }
    },
  );

  test('v173 adds plaster material layout exclusion flag', () async {
    final dbPath = join(createTempDir(), 'plaster_material_v173.db');
    final db = await CliDatabaseFactory().openDatabase(
      dbPath,
      options: OpenDatabaseOptions(),
    );

    try {
      await db.execute('''
CREATE TABLE plaster_material_size (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  supplier_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  unit_system TEXT NOT NULL,
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
)
''');
      await db.insert('plaster_material_size', {
        'supplier_id': 7,
        'name': '1200 x 6000',
        'unit_system': 'metric',
        'width': 12000,
        'height': 60000,
        'created_date': '2026-03-24T00:00:00.000',
        'modified_date': '2026-03-24T00:00:00.000',
      });

      final source = ProjectScriptSource();
      final sql = await source.loadSQL('assets/sql/upgrade_scripts/v173.sql');
      final statements = await parseSqlFile(sql);
      for (final statement in statements) {
        await db.execute(statement);
      }

      final columns = await db.rawQuery(
        'PRAGMA table_info(plaster_material_size)',
      );
      final names = {
        for (final row in columns) row['name'] as String? ?? '': true,
      };
      final rows = await db.query('plaster_material_size');

      expect(names.containsKey('excluded_from_layout'), isTrue);
      expect(rows.single['excluded_from_layout'], 0);
    } finally {
      await db.close();
      delete(dbPath);
    }
  });
}

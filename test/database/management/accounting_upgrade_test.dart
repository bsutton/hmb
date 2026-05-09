@Tags(['flutter'])
library;

import 'package:dcli/dcli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/database/versions/implementations/project_script_source.dart';
import 'package:path/path.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test(
    'v185 normalises single receipt job allocations to tax-exclusive total',
    () async {
      final dbPath = join(createTempDir(), 'accounting_v185.db');
      final db = await CliDatabaseFactory().openDatabase(
        dbPath,
        options: OpenDatabaseOptions(),
      );

      try {
        await db.execute('''
CREATE TABLE invoice_line (
  id INTEGER PRIMARY KEY AUTOINCREMENT
)
''');
        await db.execute('''
CREATE TABLE credit_note_line (
  id INTEGER PRIMARY KEY AUTOINCREMENT
)
''');
        await db.execute('''
CREATE TABLE receipt (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  total_excluding_tax INTEGER NOT NULL
)
''');
        await db.execute('''
CREATE TABLE receipt_job_allocation (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,
  job_id INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  modified_date TEXT NOT NULL
)
''');

        await db.insert('receipt', {'id': 1, 'total_excluding_tax': 2000});
        await db.insert('receipt_job_allocation', {
          'id': 1,
          'receipt_id': 1,
          'job_id': 10,
          'amount': 2200,
          'modified_date': '2026-05-01T00:00:00.000',
        });
        await db.insert('receipt', {'id': 2, 'total_excluding_tax': 8000});
        await db.insert('receipt_job_allocation', {
          'id': 2,
          'receipt_id': 2,
          'job_id': 20,
          'amount': 3000,
          'modified_date': '2026-05-01T00:00:00.000',
        });
        await db.insert('receipt_job_allocation', {
          'id': 3,
          'receipt_id': 2,
          'job_id': 21,
          'amount': 5000,
          'modified_date': '2026-05-01T00:00:00.000',
        });

        final source = ProjectScriptSource();
        final sql = await source.loadSQL('assets/sql/upgrade_scripts/v185.sql');
        final statements = await parseSqlFile(sql);
        for (final statement in statements) {
          await db.execute(statement);
        }

        final single = await db.query(
          'receipt_job_allocation',
          where: 'id = ?',
          whereArgs: [1],
        );
        final split = await db.query(
          'receipt_job_allocation',
          where: 'receipt_id = ?',
          whereArgs: [2],
          orderBy: 'id ASC',
        );

        expect(single.single['amount'], 2000);
        expect(split.map((row) => row['amount']), [3000, 5000]);
      } finally {
        await db.close();
        delete(dbPath);
      }
    },
  );

  test(
    'v186 scales split receipt job allocations from inclusive to exclusive',
    () async {
      final dbPath = join(createTempDir(), 'accounting_v186.db');
      final db = await CliDatabaseFactory().openDatabase(
        dbPath,
        options: OpenDatabaseOptions(),
      );

      try {
        await db.execute('''
CREATE TABLE receipt (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  total_excluding_tax INTEGER NOT NULL,
  total_including_tax INTEGER NOT NULL
)
''');
        await db.execute('''
CREATE TABLE receipt_job_allocation (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,
  job_id INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  modified_date TEXT NOT NULL
)
''');

        await db.insert('receipt', {
          'id': 1,
          'total_excluding_tax': 7273,
          'total_including_tax': 8000,
        });
        await db.insert('receipt_job_allocation', {
          'id': 1,
          'receipt_id': 1,
          'job_id': 20,
          'amount': 3000,
          'modified_date': '2026-05-01T00:00:00.000',
        });
        await db.insert('receipt_job_allocation', {
          'id': 2,
          'receipt_id': 1,
          'job_id': 21,
          'amount': 5000,
          'modified_date': '2026-05-01T00:00:00.000',
        });

        await db.insert('receipt', {
          'id': 2,
          'total_excluding_tax': 8000,
          'total_including_tax': 8800,
        });
        await db.insert('receipt_job_allocation', {
          'id': 3,
          'receipt_id': 2,
          'job_id': 30,
          'amount': 3000,
          'modified_date': '2026-05-01T00:00:00.000',
        });
        await db.insert('receipt_job_allocation', {
          'id': 4,
          'receipt_id': 2,
          'job_id': 31,
          'amount': 5000,
          'modified_date': '2026-05-01T00:00:00.000',
        });

        final source = ProjectScriptSource();
        final sql = await source.loadSQL('assets/sql/upgrade_scripts/v186.sql');
        final statements = await parseSqlFile(sql);
        for (final statement in statements) {
          await db.execute(statement);
        }

        final scaled = await db.query(
          'receipt_job_allocation',
          where: 'receipt_id = ?',
          whereArgs: [1],
          orderBy: 'id ASC',
        );
        final unchanged = await db.query(
          'receipt_job_allocation',
          where: 'receipt_id = ?',
          whereArgs: [2],
          orderBy: 'id ASC',
        );

        expect(scaled.map((row) => row['amount']), [2727, 4546]);
        expect(unchanged.map((row) => row['amount']), [3000, 5000]);
      } finally {
        await db.close();
        delete(dbPath);
      }
    },
  );
}

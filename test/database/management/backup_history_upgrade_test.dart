import 'package:dcli/dcli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/database/versions/implementations/project_script_source.dart';
import 'package:hmb/database/versions/pre_upgrade/pre_upgrade_154.dart';
import 'package:path/path.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test('prev154Upgrade repairs legacy backup history schema', () async {
    final dbPath = join(createTempDir(), 'backup_history_legacy.db');
    final db = await CliDatabaseFactory().openDatabase(
      dbPath,
      options: OpenDatabaseOptions(),
    );

    try {
      await db.execute('''
CREATE TABLE backup_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  backup_type TEXT NOT NULL,
  provider TEXT NOT NULL,
  success INTEGER NOT NULL,
  path_to TEXT,
  error TEXT,
  created_date TEXT NOT NULL
)
''');
      await db.insert('backup_history', {
        'backup_type': 'database',
        'provider': 'local',
        'success': 1,
        'path_to': '/tmp/example.zip',
        'error': null,
        'created_date': '2026-03-24T00:00:00.000',
      });

      await prev154Upgrade(db);

      final sql = await ProjectScriptSource().loadSQL(
        'assets/sql/upgrade_scripts/v154.sql',
      );
      final statements = await parseSqlFile(sql);
      for (final statement in statements) {
        await db.execute(statement);
      }

      final columns = await db.rawQuery('PRAGMA table_info(backup_history)');
      final names = {
        for (final row in columns) row['name'] as String? ?? '': true,
      };
      final rows = await db.query('backup_history');
      final indexes = await db.rawQuery('''
SELECT name
FROM sqlite_master
WHERE type = 'index'
AND name = 'backup_history_op_success_when_idx'
''');

      expect(names.containsKey('operation'), isTrue);
      expect(names.containsKey('occurred_at'), isTrue);
      expect(names.containsKey('modified_date'), isTrue);
      expect(rows.single['operation'], 'backup');
      expect(rows.single['occurred_at'], '2026-03-24T00:00:00.000');
      expect(indexes, hasLength(1));
    } finally {
      await db.close();
      delete(dbPath);
    }
  });
}

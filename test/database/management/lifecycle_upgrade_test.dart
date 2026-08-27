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
  test('v211 creates lifecycle audit and retires ToBeBilled', () async {
    final dbPath = join(createTempDir(), 'lifecycle_v211.db');
    final db = await CliDatabaseFactory().openDatabase(
      dbPath,
      options: OpenDatabaseOptions(),
    );
    try {
      await db.execute('''
CREATE TABLE job (
  id INTEGER PRIMARY KEY,
  status_id TEXT NOT NULL
)
''');
      await db.insert('job', {'id': 1, 'status_id': 'ToBeBilled'});

      final sql = await ProjectScriptSource().loadSQL(
        'assets/sql/upgrade_scripts/v211.sql',
      );
      for (final statement in await parseSqlFile(sql)) {
        await db.execute(statement);
      }

      expect((await db.query('job')).single['status_id'], 'Completed');
      final columns = await db.rawQuery(
        'PRAGMA table_info(lifecycle_transition)',
      );
      expect(
        columns.map((column) => column['name']),
        containsAll([
          'aggregate_type',
          'aggregate_id',
          'job_id',
          'event',
          'from_state',
          'to_state',
          'source',
          'correlation_id',
          'occurred_at',
        ]),
      );
    } finally {
      await db.close();
      delete(dbPath);
    }
  });
}

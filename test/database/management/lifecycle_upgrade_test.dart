@Tags(['flutter'])
library;

import 'package:dcli/dcli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/management/backup_providers/dev/dev_backup_provider.dart';
import 'package:hmb/database/management/db_utility.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/database/versions/implementations/project_script_source.dart';
import 'package:path/path.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test('v212 creates lifecycle audit and retires ToBeBilled', () async {
    final dbPath = join(createTempDir(), 'lifecycle_v212.db');
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

      // Model an installed v211 database. The manifest-driven upgrader must
      // select v212 without replaying the already-shipped v211 task repair.
      final source = _LifecycleScriptSource();
      final versionSql = await source.loadSQL(
        'assets/sql/upgrade_scripts/v71.sql',
      );
      for (final statement in await parseSqlFile(versionSql)) {
        await db.execute(statement);
      }
      await db.setVersion(211);
      expect(await getLatestVersion(source), 212);
      await upgradeDb(
        db: db,
        oldVersion: await db.getVersion(),
        newVersion: 212,
        backup: false,
        src: source,
        backupProvider: DevBackupProvider(CliDatabaseFactory()),
      );
      expect(await getUpgradeResumeVersion(db, 211), 212);
      // A resumed upgrade must not replay the lifecycle table/column creation.
      await upgradeDb(
        db: db,
        oldVersion: 211,
        newVersion: 212,
        backup: false,
        src: source,
        backupProvider: DevBackupProvider(CliDatabaseFactory()),
      );

      expect((await db.query('job')).single['status_id'], 'Completed');
      final jobColumns = await db.rawQuery('PRAGMA table_info(job)');
      expect(
        jobColumns.map((column) => column['name']),
        contains('resume_status_id'),
      );
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

// This regression models only the v211 schema required by v212.
class _LifecycleScriptSource extends ProjectScriptSource {
  @override
  Future<List<String>> upgradeScripts() async => (await super.upgradeScripts())
      .where((path) => extractVerionForSQLUpgradeScript(path) <= 212)
      .toList();
}

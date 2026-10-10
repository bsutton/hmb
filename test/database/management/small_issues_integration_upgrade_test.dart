@Tags(['flutter'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/cancelled_schedule.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/management/backup_providers/dev/dev_backup_provider.dart';
import 'package:hmb/database/management/db_utility.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/database/versions/implementations/project_script_source.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'test_database_config.dart';

void main() {
  test('combined registry contains unique versions through v224', () async {
    final source = ProjectScriptSource();
    final paths = await source.upgradeScripts();
    final versions = paths.map(extractVerionForSQLUpgradeScript).toList();
    expect(versions.toSet(), hasLength(versions.length));
    expect(versions.where((version) => version == 223), hasLength(1));
    expect(versions.where((version) => version == 224), hasLength(1));
    expect(await getLatestVersion(source), 224);
    for (final path in paths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  for (final previous in [
    (211, 211, false),
    (221, 221, false),
    (222, 222, false),
    (223, 223, false),
    (224, 224, false),
    // Interrupted open: HMB recorded a migration before SQLite user_version.
    (222, 223, false),
    (223, 224, false),
    (223, 223, true),
  ]) {
    test('upgrade/resume SQLite ${previous.$1}, HMB ${previous.$2}, '
        'unrecorded DDL: ${previous.$3}', () async {
      final directory = Directory.systemTemp.createTempSync('hmb-combined-');
      final path = '${directory.path}/fixture.db';
      File('test/fixture/db/handyman_test.db').copySync(path);
      final db = await CliDatabaseFactory().openDatabase(
        path,
        options: OpenDatabaseOptions(
          onConfigure: configureDisposableTestDatabase,
        ),
      );
      try {
        Future<void> upgrade(int target, ProjectScriptSource source) =>
            upgradeDb(
              db: db,
              oldVersion: previous.$1,
              newVersion: target,
              backup: false,
              src: source,
              backupProvider: DevBackupProvider(CliDatabaseFactory()),
            );

        // Build real prior schemas from the tracked v211 fixture. The source
        // is capped because upgradeDb selects scripts from the registry.
        final seedVersion = previous.$2 > 222 ? 222 : previous.$2;
        await upgradeDb(
          db: db,
          oldVersion: 211,
          newVersion: seedVersion,
          backup: false,
          src: _ThroughVersion(seedVersion),
          backupProvider: DevBackupProvider(CliDatabaseFactory()),
        );
        for (final sql in await parseSqlFile(
          File('test/sql/message_template_site_address.sql').readAsStringSync(),
        )) {
          await db.execute(sql);
        }
        if (previous.$2 > seedVersion) {
          await upgradeDb(
            db: db,
            oldVersion: seedVersion,
            newVersion: previous.$2,
            backup: false,
            src: _ThroughVersion(previous.$2),
            backupProvider: DevBackupProvider(CliDatabaseFactory()),
          );
        }
        if (previous.$3) {
          // Simulate a stop after DDL commits but before migration history.
          await db.execute(
            File('assets/sql/upgrade_scripts/v224.sql').readAsStringSync(),
          );
          await db.execute(
            File('test/sql/cancelled_schedule.sql').readAsStringSync(),
          );
        }
        await db.setVersion(previous.$1);
        final jobsBefore = await db.query('job');
        final activitiesBefore = await db.query('job_activity');
        final source = _RecordingSource();
        await upgrade(224, source);
        expect(await getUpgradeResumeVersion(db, previous.$1), 224);
        final applied = source.loadedVersions.where((v) => v >= 223).toList();
        expect(applied, [
          if (previous.$2 < 223) 223,
          if (previous.$2 < 224) 224,
        ]);
        final jobsAfter = await db.query('job');
        expect(
          jobsAfter.map((row) => row['id']),
          jobsBefore.map((row) => row['id']),
        );
        if (previous.$2 >= 221) {
          expect(jobsAfter, jobsBefore);
        }
        expect(await db.query('job_activity'), activitiesBefore);
        final templates = await db.query(
          'message_template',
          where: "title LIKE '654 %'",
          orderBy: 'title',
        );
        expect(
          templates[0]['message'],
          'Custom wording\n\nSite: {{site.address}}',
        );
        expect(templates[0]['enabled'], 0);
        expect(templates[1]['message'], 'Email wording');
        expect(templates[2]['message'], 'Meet at {{site.address}} please');
        if (!previous.$3) {
          await db.execute(
            File('test/sql/cancelled_schedule.sql').readAsStringSync(),
          );
        }
        final archive = (await db.query(CancelledSchedule.table)).single;
        expect(CancelledSchedule.activity(archive).notes, 'Archived fixture');

        // A repeated/resumed upgrade must neither duplicate the SMS suffix
        // nor recreate the archive table, discard history, or duplicate audit.
        source.loadedVersions.clear();
        await upgrade(224, source);
        expect(source.loadedVersions, isEmpty);
        expect(
          await db.query(
            'message_template',
            where: "title LIKE '654 %'",
            orderBy: 'title',
          ),
          templates,
        );
        expect(await db.query(CancelledSchedule.table), [archive]);
        final versions = await db.query(
          'version',
          columns: ['db_version'],
          where: 'db_version IN (223, 224)',
          orderBy: 'id',
        );
        expect(versions.map((row) => row['db_version']), [223, 224]);
      } finally {
        await db.close();
        directory.deleteSync(recursive: true);
      }
    });
  }
}

class _ThroughVersion extends ProjectScriptSource {
  _ThroughVersion(this.maximum);
  final int maximum;
  @override
  Future<List<String>> upgradeScripts() async => (await super.upgradeScripts())
      .where((path) => extractVerionForSQLUpgradeScript(path) <= maximum)
      .toList();
}

class _RecordingSource extends ProjectScriptSource {
  final loadedVersions = <int>[];
  @override
  Future<String> loadSQL(String pathToScript) {
    loadedVersions.add(extractVerionForSQLUpgradeScript(pathToScript));
    return super.loadSQL(pathToScript);
  }
}

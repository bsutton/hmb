@Tags(['flutter'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/management/backup_providers/dev/dev_backup_provider.dart';
import 'package:hmb/database/management/db_utility.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/database/versions/implementations/project_script_source.dart';
import 'package:hmb/entity/contact.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test('v213 preserves roles, primary and existing billing outcomes', () async {
    final directory = Directory.systemTemp.createTempSync('hmb_role_upgrade_');
    final db = await CliDatabaseFactory().openDatabase(
      '${directory.path}/test.db',
      options: OpenDatabaseOptions(),
    );
    try {
      final source = _JobPartiesScriptSource();
      for (final path in [
        'test/sql/job_parties_v212.sql',
        'assets/sql/upgrade_scripts/v71.sql',
      ]) {
        for (final sql in await parseSqlFile(await source.loadSQL(path))) {
          await db.execute(sql);
        }
      }
      await db.execute('PRAGMA foreign_keys = ON');
      await db.setVersion(212);
      await upgradeDb(
        db: db,
        oldVersion: 212,
        newVersion: 213,
        backup: false,
        src: source,
        backupProvider: DevBackupProvider(CliDatabaseFactory()),
      );

      final roles = await db.query('contact_role');
      expect(roles.where((row) => row['builtin'] == 1), hasLength(9));
      expect(roles.where((row) => row['builtin'] == 0), hasLength(1));
      final contacts = (await db.query(
        'contact',
        orderBy: 'id',
      )).map(Contact.fromMap).toList();
      expect(contacts[0].defaultRoleId, contacts[1].defaultRoleId);
      expect(contacts[0].roleDescription, contacts[1].roleDescription);
      expect(contacts[2].defaultRoleId, 1);
      expect(contacts[3].defaultRoleId, isNull);

      final parties = await db.query('job_party', where: 'job_id = 1');
      expect(parties, hasLength(3));
      expect(parties.where((p) => p['contact_id'] == 1), hasLength(2));
      expect(parties.map((p) => p['role_id']), containsAll([1, 5, 7]));
      expect(parties.any((p) => p['role_id'] == 9), isFalse);
      final job = (await db.query('job', where: 'id = 1')).single;
      expect(job['bill_to_customer_id'], 20);
      expect(job['legacy_billing_contact_id'], 2);
      expect(job['contact_id'], 1);
      expect(job['billing_contact_id'], isNull);
      final invoices = await db.query('invoice', orderBy: 'id');
      expect(invoices.map((row) => row['billing_contact_id']), [2, 3, 4]);
      expect(invoices.map((row) => row['billing_customer_id']), [20, 20, 30]);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);

      // The version history prevents applying the additive schema twice.
      await upgradeDb(
        db: db,
        oldVersion: 212,
        newVersion: 213,
        backup: false,
        src: source,
        backupProvider: DevBackupProvider(CliDatabaseFactory()),
      );
      expect(await db.query('job_party'), hasLength(5));
    } finally {
      await db.close();
      directory.deleteSync(recursive: true);
    }
  });
}

class _JobPartiesScriptSource extends ProjectScriptSource {
  @override
  Future<List<String>> upgradeScripts() async => (await super.upgradeScripts())
      .where((path) => extractVerionForSQLUpgradeScript(path) <= 213)
      .toList();
}

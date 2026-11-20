import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/database/versions/implementations/project_script_source.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test(
    'v230 makes a legacy void eligible without changing its history',
    () async {
      final db = await CliDatabaseFactory().openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(),
      );
      try {
        final source = ProjectScriptSource();
        const migration = 'assets/sql/upgrade_scripts/v230.sql';
        expect(await source.upgradeScripts(), contains(migration));
        for (final script in [
          File(
            'test/sql/voided_invoice_cancellation_v229.sql',
          ).readAsStringSync(),
          await source.loadSQL(migration),
          await source.loadSQL(migration), // Safe if startup retries.
        ]) {
          for (final statement in await parseSqlFile(script)) {
            await db.execute(statement);
          }
        }

        final eligible = await db.query('cancellation_rejectable_quote');
        expect(eligible, [
          {'id': 178},
        ]);
        expect((await db.query('job')).single['status_id'], 'awaitingPayment');
        expect(
          (await db.query('quote', where: 'id = 178')).single['state'],
          'invoiced',
        );
        expect((await db.query('invoice')).first['external_sync_status'], 3);
        expect((await db.query('milestone')).first['invoice_id'], 8);
        expect(
          (await db.query('billing_allocation')).first['released_date'],
          isNull,
        );
        await expectLater(
          db.update('quote', {'total_amount': 1}, where: 'id = 178'),
          throwsException,
        );
        await expectLater(
          db.update('quote', {'state': 'sent'}, where: 'id = 178'),
          throwsException,
        );
        await expectLater(
          db.update('quote', {'state': 'rejected'}, where: 'id = 179'),
          throwsException,
        );
        await db.update('quote', {'state': 'rejected'}, where: 'id = 178');
      } finally {
        await db.close();
      }
    },
  );
}

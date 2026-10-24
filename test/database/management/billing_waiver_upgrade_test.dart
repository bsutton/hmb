import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/billing_waiver.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test(
    'v229 adds audited waivers and requeues old billing decisions',
    () async {
      final db = await CliDatabaseFactory().openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(),
      );
      try {
        for (final path in [
          'test/sql/billing_waiver_v228.sql',
          'assets/sql/upgrade_scripts/v229.sql',
        ]) {
          for (final sql in await parseSqlFile(File(path).readAsStringSync())) {
            await db.execute(sql);
          }
        }
        final state = (await db.query('job_billing_state')).single;
        expect(state['revision'], 6);
        expect(state['checked_revision'], 5);
        expect(state['failed'], 0);
        final row = <String, Object?>{
          'job_id': 1,
          'source_type': 'time',
          'source_id': 10,
          'source_hash': 'snapshot',
          'description': 'Unbilled labour',
          'amount': 6600,
          'reason': 'Too late to bill',
          'waived_date': '2026-10-25T10:00:00',
        };
        await db.insert('billing_waiver', row);
        final waiver = BillingWaiver.fromMap(
          (await db.query('billing_waiver')).single,
        );
        expect(waiver.sourceKey, 'time:10');
        expect(waiver.reason, 'Too late to bill');
        await expectLater(db.insert('billing_waiver', row), throwsException);
        await db.update('billing_waiver', {'restored_date': '2026-10-26'});
        await db.insert('billing_waiver', row);
        expect(await db.query('billing_waiver'), hasLength(2));
      } finally {
        await db.close();
      }
    },
  );
}

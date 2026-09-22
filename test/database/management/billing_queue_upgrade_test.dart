import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/billing_queue.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test(
    'v214 queues existing jobs without changing source flags or links',
    () async {
      final directory = Directory.systemTemp.createTempSync('billing_upgrade_');
      final db = await CliDatabaseFactory().openDatabase(
        '${directory.path}/db',
        options: OpenDatabaseOptions(),
      );
      try {
        for (final path in [
          'test/sql/billing_queue_v213.sql',
          'assets/sql/upgrade_scripts/v214.sql',
        ]) {
          for (final sql in await parseSqlFile(
            await File(path).readAsString(),
          )) {
            await db.execute(sql);
          }
        }
        expect(await db.query('job_billing_state'), hasLength(2));
        expect(
          (await db.query(
            'job',
            where: 'id = 1',
          )).single['booking_fee_invoiced'],
          1,
        );
        expect((await db.query('milestone')).single['invoice_id'], 9);
        expect(
          await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'trigger'",
          ),
          isEmpty,
        );
        await BillingQueue(db, check: (_) async => null).drain();
        expect(
          (await db.query(
            'job_billing_state',
          )).every((row) => row['billing_required'] == 0),
          isTrue,
        );
      } finally {
        await db.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}

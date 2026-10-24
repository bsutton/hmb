import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test(
    'v228 preserves existing overpayments and accepts new credit kinds',
    () async {
      final db = await CliDatabaseFactory().openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(),
      );
      try {
        await db.execute('CREATE TABLE customer (id INTEGER PRIMARY KEY)');
        for (final path in [
          'assets/sql/upgrade_scripts/v227.sql',
          'test/sql/xero_customer_credit_v227.sql',
          'assets/sql/upgrade_scripts/v228.sql',
        ]) {
          for (final sql in await parseSqlFile(File(path).readAsStringSync())) {
            await db.execute(sql);
          }
        }
        final row = (await db.query('xero_customer_credit')).single;
        expect(row['credit_kind'], 'overpayment');
        expect(row['remaining_credit'], 10000);
        for (final kind in ['prepayment', 'credit_note']) {
          await db.insert('xero_customer_credit', {
            ...row,
            'external_id': kind,
            'credit_kind': kind,
          });
        }
        expect(await db.query('xero_customer_credit'), hasLength(3));
      } finally {
        await db.close();
      }
    },
  );
}

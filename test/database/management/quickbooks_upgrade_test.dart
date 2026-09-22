import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test(
    'QuickBooks migration preserves old invoices and restricts deletion',
    () async {
      final directory = Directory.systemTemp.createTempSync('qbo_upgrade_');
      final db = await CliDatabaseFactory().openDatabase(
        '${directory.path}/test.db',
        options: OpenDatabaseOptions(),
      );
      try {
        await db.execute('PRAGMA foreign_keys = ON');
        for (final path in [
          'test/sql/quickbooks_v213.sql',
          'assets/sql/upgrade_scripts/v221.sql',
        ]) {
          for (final sql in await parseSqlFile(
            await File(path).readAsString(),
          )) {
            await db.execute(sql);
          }
        }
        expect((await db.query('invoice')).single['total_amount'], 11000);
        expect((await db.query('quickbooks_settings')).single['sandbox'], 1);
        await db.insert('quickbooks_invoice_export', {
          'invoice_id': 1,
          'realm_id': '42',
          'sandbox': 1,
          'request_id': 'stable',
          'payload_json': '{}',
        });
        await expectLater(
          db.delete('invoice', where: 'id = 1'),
          throwsA(isA<DatabaseException>()),
        );
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        await db.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}

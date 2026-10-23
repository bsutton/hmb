import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_base.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/entity/invoice.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'test_database_config.dart';

void main() {
  test(
    'billing migration preserves documents and flags ambiguous history',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'hmb-billing-upgrade-',
      );
      final db = await CliDatabaseFactory().openDatabase(
        '${directory.path}/test.db',
        options: OpenDatabaseOptions(
          onConfigure: configureDisposableTestDatabase,
        ),
      );
      try {
        for (final path in [
          'test/sql/billing_v225.sql',
          'assets/sql/upgrade_scripts/v226.sql',
        ]) {
          for (final sql in await parseSqlFile(
            await File(path).readAsString(),
          )) {
            await db.execute(sql);
          }
        }
        final invoice = await DaoBase<Invoice>.direct(
          db,
          'invoice',
          Invoice.fromMap,
        ).getById(1);
        expect(invoice!.totalAmount, MoneyEx.dollars(300));
        expect(invoice.sent, isTrue);
        expect(invoice.createdDate, DateTime(2026, 6, 1, 9));
        final claims = await db.query('billing_allocation');
        expect(
          claims.map((r) => r['source_type']),
          unorderedEquals(['time', 'item', 'milestone', 'booking_fee']),
        );
        expect((await db.query('task')).single['billing_type'], 'fixedPrice');
        final reviews = (await db.query(
          'billing_review',
        )).map((r) => r['reason']);
        expect(reviews, contains('Historical void date is unknown'));
        expect(
          reviews,
          contains('Billed time has a missing invoice-line link'),
        );
        expect(
          (await db.query('invoice', where: 'id = 2')).single['voided_date'],
          isNull,
        );
        await db.update('invoice', {
          'external_sync_status': 3,
        }, where: 'id = 1');
        expect(
          (await db.query('invoice', where: 'id = 1')).single['voided_date'],
          isNotNull,
        );
        await expectLater(
          db.update('milestone', {'payment_amount': 31000}, where: 'id = 1'),
          throwsException,
        );
      } finally {
        await db.close();
        directory.deleteSync(recursive: true);
      }
    },
  );

  test(
    'SQL parser keeps trigger statements and CASE expressions together',
    () async {
      final statements = await parseSqlFile("""
CREATE TABLE example (value TEXT);
CREATE TRIGGER example_update AFTER INSERT ON example
BEGIN
 UPDATE example SET value = CASE WHEN NEW.value = 'BEGIN;END' THEN 'END'
 ELSE 'CASE' END;
 UPDATE example SET value = 'done;';
END;
INSERT INTO example VALUES ('test');
""");
      expect(statements, hasLength(3));
      expect(statements[1], contains("value = 'done;';"));
    },
  );
}

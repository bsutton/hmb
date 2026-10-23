import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/nav/dashboards/accounting/accountant_tax_pack_screen.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';
import '../util/settings_test_helper.dart';

void main() {
  setUpAll(prepareSettingsTest);
  setUp(() async {
    await resetSettingsForTest();
    await setupTestDb();
  });
  tearDown(tearDownTestDb);

  test(
    'pack contains numeric workbook and detailed stable registers',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
      );
      await DaoInvoice().insert(
        Invoice.forInsert(
          jobId: job.id,
          billingContactId: job.billingContactId,
          totalAmount: MoneyEx.dollars(110),
          dueDate: LocalDate.today(),
        ),
      );
      final file = await AccountantTaxPackBuilder().build(
        AccountingPeriod.forMonth(DateTime.now()),
      );
      try {
        final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
        final sales = utf8.decode(
          archive.findFile('Sales invoices.csv')!.content,
        );
        expect(sales, contains('"110.00"'));
        expect(sales, contains('"unknown"'));
        expect(archive.findFile('Payment allocations.csv'), isNotNull);
        expect(archive.findFile('Expense lines.csv'), isNotNull);
        final workbook = ZipDecoder().decodeBytes(
          archive.findFile('accountant_workbook.xlsx')!.content,
        );
        final xml = workbook.files
            .where((f) => f.name.startsWith('xl/worksheets/'))
            .map((f) => utf8.decode(f.content))
            .join();
        expect(xml, contains('s="2"><v>110.00</v>'));
        expect(xml, isNot(contains('&amp;#')));
      } finally {
        await file.parent.delete(recursive: true);
      }
    },
  );
}

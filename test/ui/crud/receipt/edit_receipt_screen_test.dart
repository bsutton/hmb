@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/receipt/edit_receipt_screen.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_field.dart';
import 'package:hmb/util/dart/log.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../../util/settings_test_helper.dart';

void main() {
  setUpAll(() async {
    await prepareSettingsTest();
    Log.configure('.');
  });
  setUp(() async {
    await resetSettingsForTest();
    await setupTestDb();
  });
  tearDown(tearDownTestDb);

  Future<void> openLines(WidgetTester tester) async {
    final receipt = await tester.runAsync(() async {
      final supplier = Supplier.forInsert(
        name: 'Test supplier',
        businessNumber: null,
        description: null,
        bsb: null,
        accountNumber: null,
        service: null,
      );
      await DaoSupplier().insert(supplier);
      final receipt = Receipt.forInsert(
        receiptDate: DateTime(2026, 9, 23),
        jobId: null,
        supplierId: supplier.id,
        totalExcludingTax: MoneyEx.dollars(10),
        tax: MoneyEx.dollars(1),
        totalIncludingTax: MoneyEx.dollars(11),
      );
      await DaoReceipt().insert(receipt);
      await DaoReceiptLineItem().insert(
        ReceiptLineItem.forInsert(
          receiptId: receipt.id,
          description: 'Paint',
          quantity: 1,
          unitPrice: MoneyEx.dollars(10),
          lineTotalExTax: MoneyEx.dollars(10),
          taxAmount: MoneyEx.dollars(1),
          lineTotalIncTax: MoneyEx.dollars(11),
          matchedTaskItemId: null,
          confidence: 100,
          source: 'manual',
        ),
      );
      return receipt;
    });
    await tester.pumpWidget(
      MaterialApp(home: ReceiptEditScreen(receipt: receipt)),
    );
    await waitFor(tester, find.text('Next'));
    await tester.tap(find.text('Next'));
    await waitFor(tester, field('Line Total Incl. Tax'));
  }

  testWidgets('receipt line decimals survive tax recalculation', (
    tester,
  ) async {
    await openLines(tester);
    final total = field('Line Total Incl. Tax');
    await tester.ensureVisible(total);
    for (final text in ['12', '12.', '12.3', '12.34']) {
      await tester.enterText(total, text);
      await tester.pump();
      expect(tester.widget<TextFormField>(total).controller!.text, text);
    }
    expect(
      tester
          .widget<TextFormField>(field('Line Total Excl. Tax'))
          .controller!
          .text,
      '11.34',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('quantity and unit price recalculate line totals', (
    tester,
  ) async {
    await openLines(tester);
    await tester.ensureVisible(field('Quantity'));
    await tester.enterText(field('Quantity'), '2.5');
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(field('Line Total Excl. Tax'))
          .controller!
          .text,
      '25',
    );
    expect(
      tester
          .widget<TextFormField>(field('Line Total Incl. Tax'))
          .controller!
          .text,
      '26',
    );
    await tester.ensureVisible(field('Unit Price Excl. Tax'));
    await tester.enterText(field('Unit Price Excl. Tax'), '4.40');
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(field('Line Total Excl. Tax'))
          .controller!
          .text,
      '11',
    );
    expect(
      tester
          .widget<TextFormField>(field('Line Total Incl. Tax'))
          .controller!
          .text,
      '12',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  });
}

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is HMBTextField && widget.labelText == label,
  ),
  matching: find.byType(TextFormField),
);

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 30));
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  expect(finder, findsWidgets);
}

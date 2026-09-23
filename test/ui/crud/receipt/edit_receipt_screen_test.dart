@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/receipt/edit_receipt_screen.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_field.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/ui/widgets/select/hmb_select_job.dart';
import 'package:hmb/util/dart/log.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money2/money2.dart';

import '../../../dao/invoice/utility.dart';
import '../../../database/management/db_utility_test_helper.dart';
import '../../../util/settings_test_helper.dart';
import '../../ui_test_helpers.dart';

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

  final jobs = <Job>[];
  final items = <TaskItem>[];

  Future<void> openLines(
    WidgetTester tester, {
    bool withJobs = false,
    bool withUnavailableMatch = false,
  }) async {
    jobs.clear();
    items.clear();
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
      if (withJobs) {
        for (final name in ['Kitchen', 'Bathroom']) {
          final job = await createJobWithCustomer(
            billingType: BillingType.timeAndMaterial,
            hourlyRate: MoneyEx.zero,
            summary: name,
          );
          jobs.add(job);
          final task = await createTask(job, 'Painting $name');
          items.add(
            await insertMaterialItem(
              task,
              itemType: TaskItemType.materialsBuy,
              completed: !withUnavailableMatch,
              description: '$name paint',
              actualQuantity: Fixed.one,
              actualUnitCost: MoneyEx.dollars(10),
            ),
          );
        }
      }
      final receipt = Receipt.forInsert(
        receiptDate: DateTime(2026, 9, 23),
        jobId: withJobs ? jobs.first.id : null,
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
          matchedTaskItemId: withUnavailableMatch ? items.last.id : null,
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
    await waitFor(tester, find.text('Primary Job'));
    await tester.tap(find.text('Next'));
    await waitFor(tester, field('Line Total Incl. Tax'));
  }

  testWidgets('new line is focused and its description uses the full row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openLines(tester);
    await tester.ensureVisible(find.text('Add Line'));
    await tester.tap(find.text('Add Line'));
    await tester.pumpAndSettle();
    final descriptions = tester
        .widgetList<HMBTextField>(
          find.byWidgetPredicate(
            (widget) =>
                widget is HMBTextField && widget.labelText == 'Description',
          ),
        )
        .toList();
    expect(descriptions, hasLength(2));
    expect(descriptions.last.focusNode!.hasFocus, isTrue);
    expect(
      tester.getSize(field('Description').last).width,
      tester.getSize(field('Quantity').last).width,
    );
    expect(field('Description').last.hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('matches default to receipt job and allow other or all jobs', (
    tester,
  ) async {
    await openLines(tester, withJobs: true);
    final picker = tester.widget<HMBDroplist<TaskItem>>(
      find.byWidgetPredicate((widget) => widget is HMBDroplist<TaskItem>),
    );
    expect(await picker.items(null), [items.first]);
    final display = picker.format(items.first);
    expect(display, contains('Job: Kitchen\nTask: Painting Kitchen'));
    expect(display, contains('Kitchen paint\nQuantity: 1'));
    expect(display, isNot(contains('Job #')));
    expect(display, isNot(contains(TaskItemType.materialsBuy.label)));
    var changes = 0;
    final filter =
        picker.headerBuilder!(
              tester.element(find.byType(ReceiptEditScreen)),
              () => changes++,
            )
            as HMBSelectJob;
    filter.onSelected!(jobs.last);
    expect(await picker.items(null), [items.last]);
    filter.onSelected!(null);
    expect(await picker.items(null), containsAll(items));
    expect(await picker.items('Bathroom'), [items.last]);
    expect(changes, 2);
    filter.onSelected!(jobs.first);
    expect(picker.formatSelection!(items.first), 'Kitchen paint');
    final pickerFinder = find.text('Select a Matched Task Item');
    await waitFor(tester, pickerFinder);
    await tester.ensureVisible(pickerFinder);
    await tester.pumpAndSettle();
    await tester.tap(pickerFinder);
    await waitFor(
      tester,
      find.textContaining('Job: Kitchen\nTask: Painting Kitchen'),
    );
    expect(find.text('Filter by Job (clear for all jobs)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('review resolves matches outside the shopping candidates', (
    tester,
  ) async {
    await openLines(tester, withJobs: true, withUnavailableMatch: true);
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    }
    await waitFor(tester, find.text('Bathroom paint'));
    expect(find.text('Task Item #${items.last.id}'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  });

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

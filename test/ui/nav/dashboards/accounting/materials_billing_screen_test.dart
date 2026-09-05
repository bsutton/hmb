import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/accounting_report_service.dart';
import 'package:hmb/dao/dao_job.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/ui/nav/dashboards/accounting/materials_billing_screen.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money2/money2.dart';

import '../../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  testWidgets('job picker defaults to active jobs and can show old jobs', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final status in [JobStatus.inProgress, JobStatus.completed]) {
        await DaoJob().insert(
          Job.forInsert(
            customerId: 1,
            summary: 'Picker ${status.name}',
            description: '',
            siteId: 1,
            contactId: 1,
            billingContactId: 1,
            status: status,
            hourlyRate: MoneyEx.zero,
            bookingFee: MoneyEx.zero,
          ),
        );
      }
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: MaterialsBillingScreen(report: MaterialBillingReport(rows: [])),
      ),
    );
    await _pumpUntil(tester, find.text('Select a Job'));
    await tester.tap(find.text('Select a Job'));
    await _pumpUntil(tester, find.textContaining('Picker inProgress'));
    expect(find.textContaining('Picker completed'), findsNothing);

    await tester.tap(find.byIcon(Icons.tune));
    await _pumpUntil(tester, find.text('Show Inactive Jobs'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Show Inactive Jobs'));
    await tester.pump();
    Navigator.of(tester.element(find.text('Show Inactive Jobs'))).pop();
    await _pumpUntil(tester, find.textContaining('Picker completed'));
    expect(find.textContaining('Picker inProgress'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('attention filter highlights material billing problems', (
    tester,
  ) async {
    final report = MaterialBillingReport(
      rows: [
        _row('Missing price item'),
        _row('Ready to bill', price: MoneyEx.dollars(10)),
        _row('Already billed', price: MoneyEx.dollars(20), billed: true),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: MaterialsBillingScreen(report: report)),
    );

    expect(find.text('3 completed'), findsOneWidget);
    expect(find.text('2 not billed'), findsOneWidget);
    expect(find.text('1 missing price'), findsOneWidget);
    expect(find.text('Missing price item'), findsOneWidget);
    expect(find.text('Ready to bill'), findsOneWidget);
    expect(find.text('Already billed'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pump();

    expect(find.text('Already billed'), findsOneWidget);
  });
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  expect(finder, findsWidgets);
}

MaterialBillingRow _row(
  String description, {
  Money? price,
  bool billed = false,
}) {
  final materialPrice = price == null
      ? null
      : MaterialPrice.items(quantity: Fixed.one, unitCost: price);
  final item = TaskItem.forInsert(
    taskId: 10,
    description: description,
    purpose: '',
    itemType: TaskItemType.materialsBuy,
    estimatedPrice: materialPrice,
    actualPrice: materialPrice,
    margin: Percentage.zero,
    chargeMode: ChargeMode.calculated,
    completed: true,
    billed: billed,
    invoiceLineId: billed ? 30 : null,
    measurementType: MeasurementType.length,
    dimension1: Fixed.zero,
    dimension2: Fixed.zero,
    dimension3: Fixed.zero,
    units: Units.m,
    url: '',
    labourEntryMode: LabourEntryMode.hours,
  );
  return MaterialBillingRow(
    taskItem: item,
    jobId: 20,
    jobSummary: 'Kitchen renovation',
    customerName: 'Test Customer',
    taskName: 'Install',
    billingType: BillingType.timeAndMaterial,
    hourlyRate: MoneyEx.dollars(80),
    invoiceId: billed ? 40 : null,
    invoiceNumber: billed ? 'INV-40' : null,
  );
}

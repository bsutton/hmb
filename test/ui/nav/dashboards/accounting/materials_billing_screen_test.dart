import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/accounting_report_service.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/ui/nav/dashboards/accounting/materials_billing_screen.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money2/money2.dart';

void main() {
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

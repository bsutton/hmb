import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/_index.g.dart';
import 'package:hmb/dao/dao_invoice_time_and_materials.dart';
import 'package:hmb/entity/_index.g.dart';
import 'package:hmb/util/format.dart';
import 'package:hmb/util/local_date.dart';
import 'package:hmb/util/money_ex.dart';
import 'package:hmb/util/percentage.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test.dart';
import 'invoice/utility.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });
  group('Invoice Creation - Time and Materials Billing', () {
    test('''
should create an invoice for time and materials job with correct rates and mark items as billed''',
        () async {
      final now = DateTime.now();
      final today = LocalDate.fromDateTime(now);
      final job = await createJob(now, BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.dollars(50), bookingFee: MoneyEx.dollars(100));
      final task = await createTask(job, 'Task 1');
      final checkList = await DaoCheckList().getByTask(task.id);

      /// Item - Labour 2 hrs, $50 ph.
      /// No effect on invoice as it is not billed
      await insertLabourEstimates(
        checkList,
        MoneyEx.fromInt(5000), // $50 labour cost
        Fixed.fromNum(2, scale: 3), // 2 hours of labour
      );

      /// book time against the job - will be invoiced - $100
      final timeEntry =
          await createTimeEntry(task, now, const Duration(hours: 2));

      // Create invoice for the job
      final invoice = await createTimeAndMaterialsInvoice(job, [task.id],
          groupByTask: false);

      // Verify that the invoice includes both time entry and material item
      final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
      expect(invoiceLines.length, equals(2));

      final invoiceGroupLines =
          await DaoInvoiceLineGroup().getByInvoiceId(invoice.id);
      expect(invoiceGroupLines.length, equals(2));

      expect(invoiceGroupLines[0].name, equals('Booking Fee'));
      expect(invoiceGroupLines[1].name, equals(formatLocalDate(today)));
      // Verify that the time entry and checklist item are marked as billed
      final billedTimeEntry = await DaoTimeEntry().getById(timeEntry.id);
      expect(billedTimeEntry?.billed, isTrue);
      expect(
          invoiceLines
              .map((line) => line.id)
              .contains(billedTimeEntry!.invoiceLineId),
          isTrue);

      // final billedMaterialItem = await DaoCheckListItem().getById(labour.id);
      // expect(billedMaterialItem?.billed, isTrue);
      // expect(
      //     invoiceLines
      //         .map((line) => line.id)
      //         .contains(billedMaterialItem!.invoiceLineId),
      //     isTrue);

      expect(invoice.totalAmount, MoneyEx.dollars(200));
    });
  });

  test('should create an invoice grouped by date', () async {
    final now = DateTime.now();
    final today = LocalDate.fromDateTime(now);
    final job = await createJob(now, BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.dollars(50));
    final task1 = await createTask(job, 'Task 1');
    final task2 = await createTask(job, 'Task 2');

    // Create time entries for both tasks

    await createTimeEntry(task1, now, const Duration(hours: 1));
    await createTimeEntry(task2, now, const Duration(hours: 2));

    // Create checklist items
    final checkList1 = await DaoCheckList().getByTask(task1.id);

    await insertMaterials(
        checkList1,
        Fixed.fromNum(2, scale: 3),
        MoneyEx.fromInt(200),
        Percentage.zero,
        await DaoCheckListItemType().getMaterialsBuy());

    // Create invoice grouped by date
    final invoice = await createTimeAndMaterialsInvoice(
        job, [task1.id, task2.id],
        groupByTask: false);

    // Verify invoice lines
    final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
    expect(invoiceLines.length, equals(3));

    final invoiceGroupLines =
        await DaoInvoiceLineGroup().getByInvoiceId(invoice.id);
    expect(invoiceGroupLines.length, equals(2));

    expect(invoiceGroupLines[0].name, equals(formatLocalDate(today)));
    expect(invoiceGroupLines[1].name, equals('Materials for ${task1.name}'));
  });

  test('should create an invoice grouped by task', () async {
    final now = DateTime.now();
    final job = await createJob(now, BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.dollars(50));
    final task1 = await createTask(job, 'Task 1');
    final task2 = await createTask(job, 'Task 2');

    // Create time entries for both tasks
    await createTimeEntry(task1, now, const Duration(hours: 1));
    await createTimeEntry(task2, now, const Duration(hours: 2));

    // Create checklist items
    final checkList1 = await DaoCheckList().getByTask(task1.id);
    await insertLabourEstimates(
      checkList1,
      MoneyEx.fromInt(2000),
      Fixed.fromNum(1, scale: 3),
    );

    // Create invoice grouped by task
    final invoice = await createTimeAndMaterialsInvoice(
        job, [task1.id, task2.id],
        groupByTask: true);

    // Verify invoice lines
    final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
    expect(invoiceLines.length, equals(3));

    final invoiceGroupLines =
        await DaoInvoiceLineGroup().getByInvoiceId(invoice.id);
    expect(invoiceGroupLines.length, equals(2));

    expect(invoiceGroupLines[0].name, equals('Task 1'));
    expect(invoiceGroupLines[1].name, equals('Task 2'));
  });
}

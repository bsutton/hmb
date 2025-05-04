import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/format.dart';
import 'package:hmb/util/local_date.dart';
import 'package:hmb/util/money_ex.dart';
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
    test(
      '''
should create an invoice for time and materials job with correct rates and mark items as billed''',
      () async {
        final now = DateTime.now();
        final today = LocalDate.fromDateTime(now);
        final job = await createJob(
          contact: await createContact('Brett', 'Sutton'),
          now,
          BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.dollars(50),
          bookingFee: MoneyEx.dollars(100),
        );
        final task = await createTask(job, 'Task 1');

        /// Item - Labour 2 hrs, $50 ph.
        /// No effect on invoice as it is not billed
        await insertLabourEstimates(
          task,
          MoneyEx.fromInt(5000), // $50 labour cost
          Fixed.fromNum(2, decimalDigits: 3), // 2 hours of labour
        );

        /// book time against the job - will be invoiced - $100
        final timeEntry = await createTimeEntry(
          task,
          now,
          const Duration(hours: 2),
        );

        // Create invoice for the job
        final invoice = await createTimeAndMaterialsInvoice(
          job,
          await createContact('Brett', 'Sutton'),
          [task.id],
          groupByTask: false,
          billBookingFee: true,
        );

        // Verify that the invoice includes both time entry and material item
        final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
        expect(invoiceLines.length, equals(2));

        final invoiceGroupLines = await DaoInvoiceLineGroup().getByInvoiceId(
          invoice.id,
        );
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
          isTrue,
        );

        // final billedMaterialItem = await DaoCheckListItem().getById(labour.id);
        // expect(billedMaterialItem?.billed, isTrue);
        // expect(
        //     invoiceLines
        //         .map((line) => line.id)
        //         .contains(billedMaterialItem!.invoiceLineId),
        //     isTrue);

        expect(invoice.totalAmount, MoneyEx.dollars(200));
      },
    );
  });

  test('should create an invoice grouped by date', () async {
    final now = DateTime.now();
    final today = LocalDate.fromDateTime(now);
    final job = await createJob(
      now,
      BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.dollars(50),
    );
    final task1 = await createTask(job, 'Task 1');
    final task2 = await createTask(job, 'Task 2');

    // Create time entries for both tasks

    await createTimeEntry(task1, now, const Duration(hours: 1));
    await createTimeEntry(task2, now, const Duration(hours: 2));

    await insertMaterials(
      task1,
      Fixed.fromNum(2, decimalDigits: 3),
      MoneyEx.fromInt(200),
      Percentage.zero,
      await DaoTaskItemType().getMaterialsBuy(),
    );

    // Create invoice grouped by date
    final invoice = await createTimeAndMaterialsInvoice(
      job,
      await createContact('Brett', 'Sutton'),
      [task1.id, task2.id],
      groupByTask: false,
      billBookingFee: true,
    );

    // Verify invoice lines
    final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
    expect(invoiceLines.length, equals(3));

    final invoiceGroupLines = await DaoInvoiceLineGroup().getByInvoiceId(
      invoice.id,
    );
    expect(invoiceGroupLines.length, equals(2));

    expect(invoiceGroupLines[0].name, equals(formatLocalDate(today)));
    expect(invoiceGroupLines[1].name, equals('Materials for ${task1.name}'));
  });

  test('should create an invoice grouped by task', () async {
    final now = DateTime.now();
    final job = await createJob(
      now,
      BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.dollars(50),
    );
    final task1 = await createTask(job, 'Task 1');
    final task2 = await createTask(job, 'Task 2');

    // Create time entries for both tasks
    await createTimeEntry(task1, now, const Duration(hours: 1));
    await createTimeEntry(task2, now, const Duration(hours: 2));

    // Create checklist items
    await insertLabourEstimates(
      task1,
      MoneyEx.fromInt(2000),
      Fixed.fromNum(1, decimalDigits: 3),
    );

    // Create invoice grouped by task
    final invoice = await createTimeAndMaterialsInvoice(
      job,
      await createContact('Brett', 'Sutton'),
      [task1.id, task2.id],
      groupByTask: true,
      billBookingFee: true,
    );

    // Verify invoice lines
    final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
    expect(invoiceLines.length, equals(3));

    final invoiceGroupLines = await DaoInvoiceLineGroup().getByInvoiceId(
      invoice.id,
    );
    expect(invoiceGroupLines.length, equals(2));

    expect(invoiceGroupLines[0].name, equals('Task 1'));
    expect(invoiceGroupLines[1].name, equals('Task 2'));
  });
}

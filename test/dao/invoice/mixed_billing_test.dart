/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/format.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

import '../../database/management/db_utility_test_helper.dart';
import 'utility.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  group('Invoice Creation - Mixed Billing', () {
    test(
      '''
mixed invoice with group-by-date keeps fixed summaries first and date-grouped T&M labour after''',
      () async {
        final now = DateTime.now();
        final job = await createJob(
          now,
          BillingType.fixedPrice,
          hourlyRate: MoneyEx.dollars(100),
        );

        final fixedTask = await createTask(
          job,
          'Fixed Task (Date Group)',
          billingType: BillingType.fixedPrice,
        );
        final tmTask = await createTask(
          job,
          'T&M Task (Date Group)',
          billingType: BillingType.timeAndMaterial,
        );

        await insertLabourEstimates(fixedTask, MoneyEx.dollars(100), Fixed.one);
        await createTimeEntry(tmTask, now, const Duration(hours: 2));

        final invoice = await createTimeAndMaterialsInvoice(
          job,
          await createContact('Brett', 'Sutton'),
          [fixedTask.id, tmTask.id],
          groupByTask: false,
          billBookingFee: false,
        );

        final groups = await DaoInvoiceLineGroup().getByInvoiceId(invoice.id);
        final today = formatLocalDate(LocalDate.fromDateTime(now));
        final fixedIndex = groups.indexWhere((g) => g.name == fixedTask.name);
        final tmDateIndex = groups.indexWhere((g) => g.name == today);
        expect(fixedIndex, isNot(-1));
        expect(tmDateIndex, isNot(-1));
        expect(fixedIndex, lessThan(tmDateIndex));
      },
    );

    test(
      '''
mixed job selecting only fixed tasks invoices only fixed work and leaves T&M unbilled''',
      () async {
        final now = DateTime.now();
        final job = await createJob(
          now,
          BillingType.fixedPrice,
          hourlyRate: MoneyEx.dollars(120),
        );
        final fixedTask = await createTask(
          job,
          'Fixed Task Only',
          billingType: BillingType.fixedPrice,
        );
        final tmTask = await createTask(
          job,
          'T&M Task Not Selected',
          billingType: BillingType.timeAndMaterial,
        );

        final fixedItem = await insertLabourEstimates(
          fixedTask,
          MoneyEx.dollars(120),
          Fixed.fromNum(2, decimalDigits: 3),
        );
        final tmTimeEntry = await createTimeEntry(
          tmTask,
          now,
          const Duration(hours: 1),
        );
        final tmMaterial = await insertMaterialItem(
          tmTask,
          itemType: TaskItemType.materialsBuy,
          actualQuantity: Fixed.one,
          actualUnitCost: MoneyEx.dollars(25),
          margin: Percentage.zero,
        );

        final invoice = await createTimeAndMaterialsInvoice(
          job,
          await createContact('Brett', 'Sutton'),
          [fixedTask.id],
          groupByTask: true,
          billBookingFee: false,
        );

        final groups = await DaoInvoiceLineGroup().getByInvoiceId(invoice.id);
        expect(groups.map((g) => g.name), equals([fixedTask.name]));

        final updatedFixed = await DaoTaskItem().getById(fixedItem.id);
        final updatedTmMaterial = await DaoTaskItem().getById(tmMaterial.id);
        final updatedTmEntry = await DaoTimeEntry().getById(tmTimeEntry.id);
        expect(updatedFixed?.billed, isTrue);
        expect(updatedTmMaterial?.billed, isFalse);
        expect(updatedTmEntry?.billed, isFalse);
      },
    );

    test(
      '''
mixed job selecting only T&M tasks does not invoice fixed task items''',
      () async {
        final now = DateTime.now();
        final job = await createJob(
          now,
          BillingType.fixedPrice,
          hourlyRate: MoneyEx.dollars(100),
        );
        final fixedTask = await createTask(
          job,
          'Fixed Task Not Selected',
          billingType: BillingType.fixedPrice,
        );
        final tmTask = await createTask(
          job,
          'T&M Task Only',
          billingType: BillingType.timeAndMaterial,
        );

        final fixedItem = await insertLabourEstimates(
          fixedTask,
          MoneyEx.dollars(100),
          Fixed.one,
        );
        final tmTimeEntry = await createTimeEntry(
          tmTask,
          now,
          const Duration(hours: 1),
        );
        final tmMaterial = await insertMaterialItem(
          tmTask,
          itemType: TaskItemType.materialsBuy,
          actualQuantity: Fixed.one,
          actualUnitCost: MoneyEx.dollars(50),
          margin: Percentage.zero,
        );

        final invoice = await createTimeAndMaterialsInvoice(
          job,
          await createContact('Brett', 'Sutton'),
          [tmTask.id],
          groupByTask: true,
          billBookingFee: false,
        );

        final groups = await DaoInvoiceLineGroup().getByInvoiceId(invoice.id);
        final groupNames = groups.map((group) => group.name).toList();
        expect(groupNames, contains(tmTask.name));
        expect(groupNames, contains('Materials for ${tmTask.name}'));
        expect(groupNames, isNot(contains(fixedTask.name)));

        final updatedFixed = await DaoTaskItem().getById(fixedItem.id);
        final updatedTmMaterial = await DaoTaskItem().getById(tmMaterial.id);
        final updatedTmEntry = await DaoTimeEntry().getById(tmTimeEntry.id);
        expect(updatedFixed?.billed, isFalse);
        expect(updatedTmMaterial?.billed, isTrue);
        expect(updatedTmEntry?.billed, isTrue);
      },
    );

    test(
      '''
mixed invoice on T&M job can bill booking fee once and still include mixed task lines''',
      () async {
        final now = DateTime.now();
        final job = await createJob(
          now,
          BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.dollars(100),
          bookingFee: MoneyEx.dollars(80),
        );
        final fixedTask = await createTask(
          job,
          'Fixed Task With Fee',
          billingType: BillingType.fixedPrice,
        );
        final tmTask = await createTask(
          job,
          'T&M Task With Fee',
          billingType: BillingType.timeAndMaterial,
        );

        await insertLabourEstimates(fixedTask, MoneyEx.dollars(100), Fixed.one);
        await createTimeEntry(tmTask, now, const Duration(hours: 1));

        final invoice = await createTimeAndMaterialsInvoice(
          job,
          await createContact('Brett', 'Sutton'),
          [fixedTask.id, tmTask.id],
          groupByTask: true,
          billBookingFee: true,
        );

        final groups = await DaoInvoiceLineGroup().getByInvoiceId(invoice.id);
        expect(groups.first.name, equals('Booking Fee'));
        expect(groups.map((g) => g.name), contains(fixedTask.name));
        expect(groups.map((g) => g.name), contains(tmTask.name));

        final lines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
        final bookingFeeLine = lines.firstWhere((line) => line.fromBookingFee);
        expect(bookingFeeLine.lineTotal, equals(MoneyEx.dollars(80)));

        final updatedJob = await DaoJob().getById(job.id);
        expect(updatedJob?.bookingFeeInvoiced, isTrue);
      },
    );

    test(
      '''
mixed invoice places fixed-price task summaries first and T&M materials at the bottom''',
      () async {
        final now = DateTime.now();
        final job = await createJob(
          now,
          BillingType.fixedPrice,
          hourlyRate: MoneyEx.dollars(100),
        );

        final fixedTask = await createTask(
          job,
          'Fixed Task',
          billingType: BillingType.fixedPrice,
        );
        final tmTask = await createTask(
          job,
          'T&M Task',
          billingType: BillingType.timeAndMaterial,
        );

        final fixedLabour = await insertLabourEstimates(
          fixedTask,
          MoneyEx.dollars(100),
          Fixed.fromNum(2, decimalDigits: 3),
        );
        final fixedMaterial = await insertMaterialItem(
          fixedTask,
          itemType: TaskItemType.materialsBuy,
          description: 'Fixed Material',
          estimatedQuantity: Fixed.one,
          estimatedUnitCost: MoneyEx.dollars(75),
          margin: Percentage.zero,
        );

        final tmTimeEntry = await createTimeEntry(
          tmTask,
          now,
          const Duration(hours: 1),
        );
        final tmMaterial = await insertMaterialItem(
          tmTask,
          itemType: TaskItemType.materialsBuy,
          description: 'T&M Material',
          actualQuantity: Fixed.fromNum(2, decimalDigits: 3),
          actualUnitCost: MoneyEx.dollars(50),
          margin: Percentage.zero,
        );

        final invoice = await createTimeAndMaterialsInvoice(
          job,
          await createContact('Brett', 'Sutton'),
          [fixedTask.id, tmTask.id],
          groupByTask: true,
          billBookingFee: false,
        );

        final invoiceGroupLines = await DaoInvoiceLineGroup().getByInvoiceId(
          invoice.id,
        );
        expect(invoiceGroupLines.length, equals(3));
        expect(invoiceGroupLines[0].name, equals('Fixed Task'));
        expect(invoiceGroupLines[1].name, equals('T&M Task'));
        expect(invoiceGroupLines[2].name, equals('Materials for T&M Task'));

        final fixedGroupLines = await DaoInvoiceLine().getByInvoiceLineGroupId(
          invoiceGroupLines[0].id,
        );
        expect(fixedGroupLines.length, equals(1));
        expect(fixedGroupLines.first.description, equals('Task: Fixed Task'));

        final updatedFixedLabour = await DaoTaskItem().getById(fixedLabour.id);
        final updatedFixedMaterial = await DaoTaskItem().getById(
          fixedMaterial.id,
        );
        expect(updatedFixedLabour?.billed, isTrue);
        expect(updatedFixedMaterial?.billed, isTrue);
        expect(
          updatedFixedLabour?.invoiceLineId,
          equals(updatedFixedMaterial?.invoiceLineId),
        );

        final updatedTmMaterial = await DaoTaskItem().getById(tmMaterial.id);
        expect(updatedTmMaterial?.billed, isTrue);
        final updatedTmTimeEntry = await DaoTimeEntry().getById(tmTimeEntry.id);
        expect(updatedTmTimeEntry?.billed, isTrue);
      },
    );

    test(
      '''
time and materials job with a fixed price task bills fixed price labour and ignores time entries''',
      () async {
        final now = DateTime.now();
        final job = await createJob(
          now,
          BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.dollars(100),
        );
        final task = await createTask(
          job,
          'Fixed Price Task',
          billingType: BillingType.fixedPrice,
        );

        await insertLabourEstimates(
          task,
          MoneyEx.dollars(50),
          Fixed.fromNum(2, decimalDigits: 3),
        );

        final timeEntry = await createTimeEntry(
          task,
          now,
          const Duration(hours: 2),
        );

        final invoice = await createTimeAndMaterialsInvoice(
          job,
          await createContact('Brett', 'Sutton'),
          [task.id],
          groupByTask: true,
          billBookingFee: false,
        );

        final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
        expect(invoiceLines.length, equals(1));
        expect(invoice.totalAmount, MoneyEx.fromInt(20020));

        final billedTimeEntry = await DaoTimeEntry().getById(timeEntry.id);
        expect(billedTimeEntry?.billed, isFalse);
      },
    );

    test(
      '''
fixed price job with a time and materials task uses time entries and actual materials''',
      () async {
        final now = DateTime.now();
        final job = await createJob(
          now,
          BillingType.fixedPrice,
          hourlyRate: MoneyEx.dollars(60),
        );
        final task = await createTask(
          job,
          'T&M Task',
          billingType: BillingType.timeAndMaterial,
        );

        await createTimeEntry(task, now, const Duration(hours: 3));

        await insertMaterialItem(
          task,
          itemType: TaskItemType.materialsBuy,
          description: 'Actual Material',
          estimatedQuantity: Fixed.one,
          estimatedUnitCost: MoneyEx.dollars(10),
          actualQuantity: Fixed.fromNum(2, decimalDigits: 3),
          actualUnitCost: MoneyEx.dollars(50),
          margin: Percentage.zero,
        );

        final incompleteItem = await insertMaterialItem(
          task,
          itemType: TaskItemType.materialsBuy,
          description: 'Incomplete Material',
          actualQuantity: Fixed.fromNum(1, decimalDigits: 3),
          actualUnitCost: MoneyEx.dollars(30),
          margin: Percentage.zero,
          completed: false,
        );

        final invoice = await createTimeAndMaterialsInvoice(
          job,
          await createContact('Brett', 'Sutton'),
          [task.id],
          groupByTask: true,
          billBookingFee: false,
        );

        final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
        expect(invoiceLines.length, equals(2));
        expect(invoice.totalAmount, MoneyEx.dollars(280));

        final updatedIncomplete = await DaoTaskItem().getById(
          incompleteItem.id,
        );
        expect(updatedIncomplete?.billed, isFalse);
      },
    );

    test(
      '''
fixed price job coerces group-by-date to group-by-task so labour task items are invoiced''',
      () async {
        final now = DateTime.now();
        final job = await createJob(
          now,
          BillingType.fixedPrice,
          hourlyRate: MoneyEx.dollars(88),
        );
        final task = await createTask(job, 'Fixed Labour Task');

        await insertLabourEstimates(
          task,
          MoneyEx.dollars(88),
          Fixed.fromNum(1, decimalDigits: 3),
        );

        // Even if caller passes groupByTask=false, fixed-price tasks
        // are emitted as a single task summary line.
        final invoice = await createTimeAndMaterialsInvoice(
          job,
          await createContact('Brett', 'Sutton'),
          [task.id],
          groupByTask: false,
          billBookingFee: false,
        );

        final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
        expect(invoiceLines.length, equals(1));
        expect(invoiceLines.first.description, contains('Task:'));
        expect(invoiceLines.first.lineTotal, isNot(MoneyEx.zero));
        expect(invoice.totalAmount, invoiceLines.first.lineTotal);
      },
    );

    test(
      '''
time and materials tools owned items bill only when a charge is specified''',
      () async {
        final now = DateTime.now();
        final job = await createJob(
          now,
          BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.dollars(50),
        );
        final task = await createTask(job, 'Tools Task');

        final zeroChargeItem = await insertMaterialItem(
          task,
          itemType: TaskItemType.toolsOwn,
          description: 'Zero Tool Hire',
          actualQuantity: Fixed.one,
          actualUnitCost: MoneyEx.zero,
          margin: Percentage.zero,
        );

        final billableItem = await insertMaterialItem(
          task,
          itemType: TaskItemType.toolsOwn,
          description: 'Scaffolding',
          actualQuantity: Fixed.one,
          actualUnitCost: MoneyEx.dollars(75),
          margin: Percentage.zero,
        );

        final invoice = await createTimeAndMaterialsInvoice(
          job,
          await createContact('Brett', 'Sutton'),
          [task.id],
          groupByTask: true,
          billBookingFee: false,
        );

        final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
        expect(invoiceLines.length, equals(1));
        expect(invoiceLines.first.description, contains('Tool hire:'));
        expect(invoiceLines.first.lineTotal, MoneyEx.dollars(75));

        final updatedZeroCharge = await DaoTaskItem().getById(
          zeroChargeItem.id,
        );
        final updatedBillable = await DaoTaskItem().getById(billableItem.id);
        expect(updatedZeroCharge?.billed, isFalse);
        expect(updatedBillable?.billed, isTrue);
      },
    );
  });
}

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

        // Even if caller passes groupByTask=false, fixed-price path must
        // still emit labour task-item lines.
        final invoice = await createTimeAndMaterialsInvoice(
          job,
          await createContact('Brett', 'Sutton'),
          [task.id],
          groupByTask: false,
          billBookingFee: false,
        );

        final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
        expect(invoiceLines.length, equals(1));
        expect(invoiceLines.first.description, contains('Labour:'));
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

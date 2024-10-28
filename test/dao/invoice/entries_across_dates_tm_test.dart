import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/_index.g.dart';
import 'package:hmb/dao/dao_invoice_time_and_materials.dart';
import 'package:hmb/entity/_index.g.dart';
import 'package:hmb/util/format.dart';
import 'package:hmb/util/local_date.dart';
import 'package:hmb/util/money_ex.dart';

import '../../database/management/db_utility_test.dart';
import 'utility.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  group('Dates', () {
    test('''
should create an invoice with work done on two different dates for the same task''',
        () async {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final job = await createJob(now, BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.dollars(50));
      final task = await createTask(job, 'Task 1');

      // Create time entries for the same task on different dates
      await createTimeEntry(task, now, const Duration(hours: 1));
      await createTimeEntry(task, tomorrow, const Duration(hours: 2));

      // Create invoice grouped by date
      final invoice = await createTimeAndMaterialsInvoice(job, [task.id],
          groupByTask: false, billBookingFee: true);

      // Verify invoice lines
      final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
      expect(invoiceLines.length, equals(2));

      final invoiceGroupLines =
          await DaoInvoiceLineGroup().getByInvoiceId(invoice.id);
      expect(invoiceGroupLines.length, equals(2));

      expect(invoiceGroupLines[0].name,
          equals(formatLocalDate(LocalDate.fromDateTime(tomorrow))));
      expect(invoiceGroupLines[1].name,
          equals(formatLocalDate(LocalDate.fromDateTime(now))));
    });

    test('''
should create an invoice with work done on two different dates for two different tasks''',
        () async {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final job = await createJob(now, BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.dollars(50));
      final task1 = await createTask(job, 'Task 1');
      final task2 = await createTask(job, 'Task 2');

      // Create time entries for different tasks on different dates
      await createTimeEntry(task1, now, const Duration(hours: 1));
      await createTimeEntry(task2, tomorrow, const Duration(hours: 2));

      // Create invoice grouped by date
      final invoice = await createTimeAndMaterialsInvoice(
          job, [task1.id, task2.id],
          groupByTask: false, billBookingFee: true);

      // Verify invoice lines
      final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
      expect(invoiceLines.length, equals(2));

      final invoiceGroupLines =
          await DaoInvoiceLineGroup().getByInvoiceId(invoice.id);
      expect(invoiceGroupLines.length, equals(2));

      expect(invoiceGroupLines[0].name,
          equals(formatLocalDate(LocalDate.fromDateTime(tomorrow))));
      expect(invoiceGroupLines[1].name,
          equals(formatLocalDate(LocalDate.fromDateTime(now))));
    });
  });
}

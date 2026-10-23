import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/app_settings.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

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

  Future<Invoice> invoice(Job job, int dollars, DateTime date) async {
    final value = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.fromDateTime(date),
      totalAmount: MoneyEx.dollars(dollars),
      billingContactId: job.contactId,
      sent: true,
    );
    await DaoInvoice().insert(value);
    await testDb!.update(
      'invoice',
      {'created_date': date.toIso8601String()},
      where: 'id = ?',
      whereArgs: [value.id],
    );
    return (await DaoInvoice().getById(value.id))!;
  }

  Future<Job> job() => createJobWithCustomer(
    billingType: BillingType.timeAndMaterial,
    hourlyRate: MoneyEx.zero,
  );

  test(
    'cash report includes a partially unallocated payment remainder',
    () async {
      final j = await job();
      final inv = await invoice(j, 100, DateTime(2026, 4));
      final p = DebtorPayment.forInsert(
        customerId: j.customerId,
        contactId: j.contactId,
        paymentDate: DateTime(2026, 4, 5),
        amount: MoneyEx.dollars(150),
      );
      await DaoDebtorPayment().insert(p);
      await DaoPaymentAllocation().insert(
        PaymentAllocation.forInsert(
          paymentId: p.id,
          invoiceId: inv.id,
          amount: MoneyEx.dollars(100),
          allocatedDate: DateTime(2026, 4, 5),
        ),
      );
      final report = await AccountingReportService().cashReceived(
        AccountingPeriod.month(2026, 4),
      );
      expect(report.total, MoneyEx.dollars(150));
      expect(
        report.rows.where((row) => row.invoiceId == null).single.amount,
        MoneyEx.dollars(50),
      );
    },
  );

  test('historical ageing excludes invoices created after cutoff', () async {
    final j = await job();
    final inv = await invoice(j, 100, DateTime(2026, 7, 5));
    final report = await AccountingReportService().agedReceivables(
      asOfDate: LocalDate(2026, 6, 30),
    );
    expect(report.rows.map((r) => r.invoiceId), isNot(contains(inv.id)));
  });

  test('historical ageing ignores payments after cutoff', () async {
    final j = await job();
    final inv = await invoice(j, 100, DateTime(2026, 6, 5));
    await DebtorLedgerService().recordPayment(
      invoiceId: inv.id,
      amount: MoneyEx.dollars(40),
      paymentDate: DateTime(2026, 7, 5),
    );
    final report = await AccountingReportService().agedReceivables(
      asOfDate: LocalDate(2026, 6, 30),
    );
    expect(report.rows.single.balance, MoneyEx.dollars(100));
  });

  test(
    'mixed recorded and unknown tax remains explicitly incomplete',
    () async {
      await AppSettings.setTaxDisplayMode(TaxDisplayMode.inclusive);
      await AppSettings.setTaxSchemeCode('uk_vat');
      final j = await job();
      await invoice(j, 120, DateTime(2026, 4));
      var report = await AccountingReportService().taxSummary(
        AccountingPeriod.month(2026, 4),
      );
      expect(report.taxCollected, MoneyEx.zero);
      expect(report.unknownTaxDocuments, 1);
      final inv = await invoice(j, 120, DateTime(2026, 4, 2));
      final group = InvoiceLineGroup.forInsert(invoiceId: inv.id, name: 'Work');
      await DaoInvoiceLineGroup().insert(group);
      await DaoInvoiceLine().insert(
        InvoiceLine.forInsert(
          invoiceId: inv.id,
          invoiceLineGroupId: group.id,
          description: 'Work',
          quantity: Fixed.one,
          unitPrice: MoneyEx.dollars(120),
          lineTotal: MoneyEx.dollars(120),
          taxAmount: MoneyEx.dollars(20),
          taxType: 'OUTPUT',
        ),
      );
      report = await AccountingReportService().taxSummary(
        AccountingPeriod.month(2026, 4),
      );
      expect(report.taxCollected, MoneyEx.dollars(20));
      expect(report.unknownTaxDocuments, 1);
      expect(report.taxCollectedIsEstimated, isFalse);
    },
  );
  test('later full payment does not erase historic debt', () async {
    final j = await job();
    final inv = await invoice(j, 100, DateTime(2026, 6, 5));
    await DebtorLedgerService().recordPayment(
      invoiceId: inv.id,
      amount: MoneyEx.dollars(100),
      paymentDate: DateTime(2026, 7, 5),
    );
    expect(
      (await AccountingReportService().agedReceivables(
        asOfDate: LocalDate(2026, 6, 30),
      )).total,
      MoneyEx.dollars(100),
    );
    expect(
      (await AccountingReportService().agedReceivables(
        asOfDate: LocalDate(2026, 7, 31),
      )).total,
      MoneyEx.zero,
    );
  });

  test(
    'later void reverses income in its own period and preserves June debt',
    () async {
      final j = await job();
      final inv = await invoice(j, 110, DateTime(2026, 6, 5));
      final group = InvoiceLineGroup.forInsert(invoiceId: inv.id, name: 'Work');
      await DaoInvoiceLineGroup().insert(group);
      await DaoInvoiceLine().insert(
        InvoiceLine.forInsert(
          invoiceId: inv.id,
          invoiceLineGroupId: group.id,
          description: 'Work',
          quantity: Fixed.one,
          unitPrice: MoneyEx.dollars(110),
          lineTotal: MoneyEx.dollars(110),
          taxAmount: MoneyEx.dollars(10),
          taxType: 'OUTPUT',
        ),
      );
      await DaoInvoice().voidInvoice(
        invoiceId: inv.id,
        description: 'Cancelled',
      );
      await testDb!.update(
        'invoice',
        {'voided_date': '2026-07-05T12:00:00'},
        where: 'id = ?',
        whereArgs: [inv.id],
      );
      final service = AccountingReportService();
      expect(
        (await service.agedReceivables(asOfDate: LocalDate(2026, 6, 30))).total,
        MoneyEx.dollars(110),
      );
      expect(
        (await service.agedReceivables(asOfDate: LocalDate(2026, 7, 31))).total,
        MoneyEx.zero,
      );
      expect(
        (await service.profitAndLoss(
          AccountingPeriod.month(2026, 6),
        )).invoiceIncome,
        MoneyEx.dollars(100),
      );
      expect(
        (await service.profitAndLoss(
          AccountingPeriod.month(2026, 7),
        )).invoiceIncome,
        -MoneyEx.dollars(100),
      );
      expect(
        (await service.taxSummary(
          AccountingPeriod.month(2026, 7),
        )).taxCollected,
        -MoneyEx.dollars(10),
      );
    },
  );
}

import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/app_settings.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';
import '../util/settings_test_helper.dart';

void main() {
  setUpAll(() async {
    await prepareSettingsTest();
  });

  setUp(() async {
    await resetSettingsForTest();
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test(
    'monthly P&L uses invoices, credits, adjustments, and receipts',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'P&L report test job',
      );
      final invoice = await _insertInvoice(job, MoneyEx.dollars(100));
      await DebtorLedgerService().createCreditNote(
        invoiceId: invoice.id,
        amount: MoneyEx.dollars(10),
        reason: 'Discount',
      );
      await _insertReceipt(job.id, MoneyEx.dollars(30));

      final report = await AccountingReportService().profitAndLossForMonth(
        DateTime.now(),
      );

      expect(report.invoiceIncome, MoneyEx.dollars(100));
      expect(report.creditNotes, MoneyEx.dollars(10));
      expect(report.debtorAdjustments, MoneyEx.zero);
      expect(report.receiptExpenses, MoneyEx.dollars(30));
      expect(report.netIncome, MoneyEx.dollars(90));
      expect(report.netProfit, MoneyEx.dollars(60));
    },
  );

  test('job profit includes receipts and debtor write-offs', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Job profit report test job',
    );
    final invoice = await _insertInvoice(job, MoneyEx.dollars(100));
    final ledger = DebtorLedgerService();
    await ledger.recordPayment(
      invoiceId: invoice.id,
      amount: MoneyEx.fromInt(9960),
    );
    await ledger.writeOffSmallBalance(
      invoiceId: invoice.id,
      reason: 'Customer underpaid by 40c',
    );
    await _insertReceipt(job.id, MoneyEx.dollars(25));

    final report = await AccountingReportService().jobProfit(job.id);

    expect(report.invoiceIncome, MoneyEx.dollars(100));
    expect(report.debtorAdjustments, MoneyEx.fromInt(40));
    expect(report.receiptExpenses, MoneyEx.dollars(25));
    expect(report.netIncome, MoneyEx.fromInt(9960));
    expect(report.netProfit, MoneyEx.fromInt(7460));
  });

  test(
    'job profit uses receipt job allocations when a receipt is split',
    () async {
      final firstJob = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'First split receipt job',
      );
      final secondJob = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Second split receipt job',
      );
      final receipt = await _insertReceipt(firstJob.id, MoneyEx.dollars(100));
      await DaoReceipt().replaceJobAllocations(receipt.id, [
        ReceiptJobAllocation.forInsert(
          receiptId: receipt.id,
          jobId: firstJob.id,
          amount: MoneyEx.dollars(40),
        ),
        ReceiptJobAllocation.forInsert(
          receiptId: receipt.id,
          jobId: secondJob.id,
          amount: MoneyEx.dollars(60),
        ),
      ]);

      final firstReport = await AccountingReportService().jobProfit(
        firstJob.id,
      );
      final secondReport = await AccountingReportService().jobProfit(
        secondJob.id,
      );
      final profitAndLoss = await AccountingReportService()
          .profitAndLossForMonth(DateTime.now());

      expect(firstReport.receiptExpenses, MoneyEx.dollars(40));
      expect(secondReport.receiptExpenses, MoneyEx.dollars(60));
      expect(profitAndLoss.receiptExpenses, MoneyEx.dollars(100));
    },
  );

  test('quarter and year periods include the expected date ranges', () {
    final quarter = AccountingPeriod.forQuarter(DateTime(2026, 5));
    final year = AccountingPeriod.forYear(DateTime(2026, 5));

    expect(quarter.startInclusive, DateTime(2026, 4));
    expect(quarter.endExclusive, DateTime(2026, 7));
    expect(year.startInclusive, DateTime(2026));
    expect(year.endExclusive, DateTime(2027));
  });

  test('financial year period uses configured start month', () async {
    await AppSettings.setFinancialYearStartMonth(7);

    final period = await AccountingPeriod.forFinancialYear(DateTime(2026, 5));

    expect(period.startInclusive, DateTime(2025, 7));
    expect(period.endExclusive, DateTime(2026, 7));
  });

  test('aged receivables buckets outstanding invoice balances', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Aged receivables report test job',
    );
    final current = await _insertInvoice(
      job,
      MoneyEx.dollars(100),
      dueDate: LocalDate(2026, 5, 10),
    );
    final thirtyDays = await _insertInvoice(
      job,
      MoneyEx.dollars(200),
      dueDate: LocalDate(2026, 4, 20),
    );
    final sixtyDays = await _insertInvoice(
      job,
      MoneyEx.dollars(300),
      dueDate: LocalDate(2026, 3, 20),
    );
    final paid = await _insertInvoice(
      job,
      MoneyEx.dollars(400),
      dueDate: LocalDate(2026, 2),
    );
    await DebtorLedgerService().recordPayment(
      invoiceId: thirtyDays.id,
      amount: MoneyEx.dollars(50),
    );
    await DebtorLedgerService().recordPayment(
      invoiceId: paid.id,
      amount: MoneyEx.dollars(400),
    );

    final report = await AccountingReportService().agedReceivables(
      asOfDate: LocalDate(2026, 5, 8),
    );

    expect(report.rows.map((row) => row.invoiceId), [
      sixtyDays.id,
      thirtyDays.id,
      current.id,
    ]);
    expect(report.buckets.current, MoneyEx.dollars(100));
    expect(report.buckets.oneToThirty, MoneyEx.dollars(150));
    expect(report.buckets.thirtyOneToSixty, MoneyEx.dollars(300));
    expect(report.total, MoneyEx.dollars(550));
  });

  test(
    'debtor statement includes opening balance and period activity',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Debtor statement report test job',
      );
      final oldInvoice = await _insertInvoice(
        job,
        MoneyEx.dollars(100),
        createdDate: DateTime(2026, 3),
      );
      final periodInvoice = await _insertInvoice(
        job,
        MoneyEx.dollars(200),
        createdDate: DateTime(2026, 4, 3),
      );
      final ledger = DebtorLedgerService();
      await ledger.recordPayment(
        invoiceId: oldInvoice.id,
        amount: MoneyEx.dollars(25),
        paymentDate: DateTime(2026, 3, 15),
      );
      await ledger.recordPayment(
        invoiceId: oldInvoice.id,
        amount: MoneyEx.dollars(40),
        paymentDate: DateTime(2026, 4, 10),
      );
      await ledger.createCreditNote(
        invoiceId: periodInvoice.id,
        amount: MoneyEx.dollars(30),
        reason: 'Statement credit',
        creditDate: DateTime(2026, 4, 12),
      );

      final report = await AccountingReportService().debtorStatement(
        customerId: job.customerId,
        startInclusive: DateTime(2026, 4),
        endExclusive: DateTime(2026, 5),
      );

      expect(report.customerId, job.customerId);
      expect(report.openingBalance, MoneyEx.dollars(75));
      expect(report.entries.map((entry) => entry.type), [
        DebtorStatementEntryType.invoice,
        DebtorStatementEntryType.payment,
        DebtorStatementEntryType.credit,
      ]);
      expect(report.closingBalance, MoneyEx.dollars(205));
    },
  );

  test('cash received reports allocated payment rows', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Cash received report test job',
    );
    final invoice = await _insertInvoice(
      job,
      MoneyEx.dollars(100),
      createdDate: DateTime(2026, 4),
    );
    await DebtorLedgerService().recordPayment(
      invoiceId: invoice.id,
      amount: MoneyEx.dollars(45),
      paymentDate: DateTime(2026, 4, 15),
      paymentMethod: 'card',
      reference: 'PAY-45',
    );

    final report = await AccountingReportService().cashReceived(
      AccountingPeriod.month(2026, 4),
    );

    expect(report.total, MoneyEx.dollars(45));
    expect(report.rows.single.invoiceId, invoice.id);
    expect(report.rows.single.paymentMethod, 'card');
    expect(report.rows.single.reference, 'PAY-45');
  });

  test('tax summary uses configured generic tax label', () async {
    await AppSettings.setTaxDisplayMode(TaxDisplayMode.inclusive);
    await AppSettings.setTaxLabel('VAT');
    await AppSettings.setTaxRatePercentText('20');
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Tax summary report test job',
    );
    await _insertInvoice(
      job,
      MoneyEx.dollars(120),
      createdDate: DateTime(2026, 4, 3),
    );
    await _insertReceipt(
      job.id,
      MoneyEx.dollars(50),
      tax: MoneyEx.dollars(10),
      receiptDate: DateTime(2026, 4, 4),
    );

    final report = await AccountingReportService().taxSummary(
      AccountingPeriod.month(2026, 4),
    );

    expect(report.taxLabel, 'VAT');
    expect(report.taxCollected, MoneyEx.dollars(20));
    expect(report.supplierTaxPaid, MoneyEx.dollars(10));
    expect(report.netTaxPosition, MoneyEx.dollars(10));
    expect(report.taxCollectedIsEstimated, isTrue);
  });

  test('tax summary prefers explicit invoice line tax when present', () async {
    await AppSettings.setTaxDisplayMode(TaxDisplayMode.inclusive);
    await AppSettings.setTaxLabel('Sales Tax');
    await AppSettings.setTaxRatePercentText('20');
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Explicit tax summary report test job',
    );
    final invoice = await _insertInvoice(
      job,
      MoneyEx.dollars(120),
      createdDate: DateTime(2026, 4, 3),
    );
    final group = InvoiceLineGroup.forInsert(
      invoiceId: invoice.id,
      name: 'Taxed work',
    );
    await DaoInvoiceLineGroup().insert(group);
    await DaoInvoiceLine().insert(
      InvoiceLine.forInsert(
        invoiceId: invoice.id,
        invoiceLineGroupId: group.id,
        description: 'Taxed labour',
        quantity: Fixed.one,
        unitPrice: MoneyEx.dollars(120),
        lineTotal: MoneyEx.dollars(120),
        taxAmount: MoneyEx.dollars(7),
        taxType: 'OUTPUT',
      ),
    );

    final report = await AccountingReportService().taxSummary(
      AccountingPeriod.month(2026, 4),
    );

    expect(report.taxLabel, 'Sales Tax');
    expect(report.taxCollected, MoneyEx.dollars(7));
    expect(report.taxCollectedIsEstimated, isFalse);
  });

  test('supplier spend groups receipt totals by supplier', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Supplier spend report test job',
    );
    final supplier = await _insertSupplier('Grouped Supplier');
    await _insertReceipt(
      job.id,
      MoneyEx.dollars(80),
      tax: MoneyEx.dollars(8),
      supplierId: supplier.id,
      receiptDate: DateTime(2026, 4, 2),
    );
    await _insertReceipt(
      job.id,
      MoneyEx.dollars(20),
      tax: MoneyEx.dollars(2),
      supplierId: supplier.id,
      receiptDate: DateTime(2026, 4, 3),
    );

    final report = await AccountingReportService().supplierSpend(
      AccountingPeriod.month(2026, 4),
    );

    expect(report.rows.single.supplierName, 'Grouped Supplier');
    expect(report.rows.single.receiptCount, 2);
    expect(report.totalExcludingTax, MoneyEx.dollars(100));
    expect(report.totalTax, MoneyEx.dollars(10));
    expect(report.totalIncludingTax, MoneyEx.dollars(110));
  });

  test('unlinked costs list receipts without task-item links', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Unlinked cost report test job',
    );
    final receipt = await _insertReceipt(
      job.id,
      MoneyEx.dollars(25),
      supplierName: 'Unlinked Supplier',
    );

    final report = await AccountingReportService().unlinkedCosts();

    expect(report.rows.map((row) => row.receiptId), contains(receipt.id));
    expect(report.total, MoneyEx.dollars(25));
  });

  test('report CSV exporter quotes comma values', () {
    final csv = AccountingReportCsvExporter().debtorStatement(
      DebtorStatementReport(
        customerId: 1,
        customerName: 'Smith, Jones',
        startInclusive: DateTime(2026, 4),
        endExclusive: DateTime(2026, 5),
        openingBalance: MoneyEx.zero,
        entries: [
          DebtorStatementEntry(
            type: DebtorStatementEntryType.invoice,
            invoiceId: 42,
            date: DateTime(2026, 4),
            description: 'Invoice, materials',
            amount: MoneyEx.dollars(10),
          ),
        ],
      ),
    );

    expect(csv, contains('"Smith, Jones"'));
    expect(csv, contains('"Invoice, materials"'));
  });
}

Future<Invoice> _insertInvoice(
  Job job,
  Money total, {
  LocalDate? dueDate,
  DateTime? createdDate,
}) async {
  final invoice = Invoice.forInsert(
    jobId: job.id,
    dueDate: dueDate ?? LocalDate.today(),
    totalAmount: total,
    billingContactId: job.billingContactId,
    sent: true,
  );
  await DaoInvoice().insert(invoice);
  if (createdDate == null) {
    return invoice;
  }
  await DaoInvoice().withoutTransaction().update(
    'invoice',
    {
      'created_date': createdDate.toIso8601String(),
      'modified_date': createdDate.toIso8601String(),
    },
    where: 'id = ?',
    whereArgs: [invoice.id],
  );
  return (await DaoInvoice().getById(invoice.id))!;
}

Future<Receipt> _insertReceipt(
  int jobId,
  Money totalExcludingTax, {
  Money? tax,
  DateTime? receiptDate,
  String supplierName = 'Report Test Supplier',
  int? supplierId,
}) async {
  final supplier = supplierId == null
      ? await _insertSupplier(supplierName)
      : (await DaoSupplier().getById(supplierId))!;
  final receipt = Receipt.forInsert(
    receiptDate: receiptDate ?? DateTime.now(),
    jobId: jobId,
    supplierId: supplier.id,
    totalExcludingTax: totalExcludingTax,
    tax: tax ?? MoneyEx.zero,
    totalIncludingTax: totalExcludingTax + (tax ?? MoneyEx.zero),
  );
  await DaoReceipt().insert(receipt);
  return receipt;
}

Future<Supplier> _insertSupplier(String name) async {
  final supplier = Supplier.forInsert(
    name: name,
    businessNumber: null,
    description: null,
    bsb: null,
    accountNumber: null,
    service: null,
  );
  await DaoSupplier().insert(supplier);
  return supplier;
}

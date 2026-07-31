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

import 'package:money2/money2.dart';

import '../api/external_accounting.dart';
import '../entity/credit_note.dart';
import '../entity/debtor_adjustment.dart';
import '../entity/invoice.dart';
import '../entity/tax_code.dart';
import '../entity/tax_scheme.dart';
import '../util/dart/app_settings.dart';
import '../util/dart/local_date.dart';
import '../util/dart/money_ex.dart';
import 'dao_customer.dart';
import 'dao_invoice.dart';
import 'dao_job.dart';
import 'dao_system.dart';
import 'dao_tax_code.dart';
import 'dao_tax_scheme.dart';
import 'debtor_ledger_service.dart';

class AccountingPeriod {
  final DateTime startInclusive;
  final DateTime endExclusive;

  const AccountingPeriod({
    required this.startInclusive,
    required this.endExclusive,
  });

  factory AccountingPeriod.month(int year, int month) => AccountingPeriod(
    startInclusive: DateTime(year, month),
    endExclusive: DateTime(year, month + 1),
  );

  factory AccountingPeriod.quarter(int year, int quarter) {
    if (quarter < 1 || quarter > 4) {
      throw ArgumentError.value(quarter, 'quarter', 'Must be between 1 and 4.');
    }
    final startMonth = ((quarter - 1) * 3) + 1;
    return AccountingPeriod(
      startInclusive: DateTime(year, startMonth),
      endExclusive: DateTime(year, startMonth + 3),
    );
  }

  factory AccountingPeriod.year(int year) => AccountingPeriod(
    startInclusive: DateTime(year),
    endExclusive: DateTime(year + 1),
  );

  factory AccountingPeriod.financialYear({
    required DateTime date,
    required int startMonth,
  }) {
    final safeStartMonth = startMonth < 1 || startMonth > 12 ? 1 : startMonth;
    final startYear = date.month < safeStartMonth ? date.year - 1 : date.year;
    return AccountingPeriod(
      startInclusive: DateTime(startYear, safeStartMonth),
      endExclusive: DateTime(startYear + 1, safeStartMonth),
    );
  }

  factory AccountingPeriod.forMonth(DateTime date) =>
      AccountingPeriod.month(date.year, date.month);

  factory AccountingPeriod.forQuarter(DateTime date) =>
      AccountingPeriod.quarter(date.year, ((date.month - 1) ~/ 3) + 1);

  factory AccountingPeriod.forYear(DateTime date) =>
      AccountingPeriod.year(date.year);

  static Future<AccountingPeriod> forFinancialYear(DateTime date) async {
    final configuredStartMonth =
        await AppSettings.getConfiguredFinancialYearStartMonth();
    return AccountingPeriod.financialYear(
      date: date,
      startMonth:
          configuredStartMonth ??
          defaultFinancialYearStartMonthForCountry(
            (await DaoSystem().get()).countryCode,
          ),
    );
  }

  static int defaultFinancialYearStartMonthForCountry(String? countryCode) {
    switch (countryCode?.trim().toUpperCase()) {
      case 'AU':
        return 7;
      case 'NZ':
      case 'GB':
      case 'UK':
      case 'IN':
        return 4;
      default:
        return AppSettings.financialYearStartMonthDefault;
    }
  }
}

class ProfitAndLossReport {
  final AccountingPeriod period;
  final Money invoiceIncome;
  final Money creditNotes;
  final Money debtorAdjustments;
  final Money receiptExpenses;

  const ProfitAndLossReport({
    required this.period,
    required this.invoiceIncome,
    required this.creditNotes,
    required this.debtorAdjustments,
    required this.receiptExpenses,
  });

  Money get netIncome => invoiceIncome - creditNotes - debtorAdjustments;

  Money get netProfit => netIncome - receiptExpenses;
}

class JobProfitReport {
  final int jobId;
  final Money invoiceIncome;
  final Money creditNotes;
  final Money debtorAdjustments;
  final Money receiptExpenses;
  final Money unreceiptedActualCosts;

  const JobProfitReport({
    required this.jobId,
    required this.invoiceIncome,
    required this.creditNotes,
    required this.debtorAdjustments,
    required this.receiptExpenses,
    required this.unreceiptedActualCosts,
  });

  Money get netIncome => invoiceIncome - creditNotes - debtorAdjustments;

  Money get totalCosts => receiptExpenses + unreceiptedActualCosts;

  Money get netProfit => netIncome - totalCosts;
}

class AgedReceivablesBucket {
  final Money current;
  final Money oneToThirty;
  final Money thirtyOneToSixty;
  final Money sixtyOneToNinety;
  final Money overNinety;

  const AgedReceivablesBucket({
    required this.current,
    required this.oneToThirty,
    required this.thirtyOneToSixty,
    required this.sixtyOneToNinety,
    required this.overNinety,
  });

  Money get total =>
      current + oneToThirty + thirtyOneToSixty + sixtyOneToNinety + overNinety;
}

class AgedReceivablesRow {
  final int invoiceId;
  final int? customerId;
  final String customerName;
  final LocalDate dueDate;
  final Money balance;
  final int daysOverdue;

  const AgedReceivablesRow({
    required this.invoiceId,
    required this.customerId,
    required this.customerName,
    required this.dueDate,
    required this.balance,
    required this.daysOverdue,
  });
}

class AgedReceivablesReport {
  final LocalDate asOfDate;
  final List<AgedReceivablesRow> rows;
  final AgedReceivablesBucket buckets;

  const AgedReceivablesReport({
    required this.asOfDate,
    required this.rows,
    required this.buckets,
  });

  Money get total => buckets.total;
}

enum DebtorStatementEntryType { invoice, payment, credit, adjustment }

class DebtorStatementEntry {
  final DebtorStatementEntryType type;
  final int invoiceId;
  final String invoiceNumber;
  final String customerName;
  final DateTime date;
  final String description;
  final Money amount;

  const DebtorStatementEntry({
    required this.type,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.customerName,
    required this.date,
    required this.description,
    required this.amount,
  });
}

class DebtorStatementReport {
  final int? customerId;
  final String customerName;
  final DateTime startInclusive;
  final DateTime endExclusive;
  final Money openingBalance;
  final List<DebtorStatementEntry> entries;

  const DebtorStatementReport({
    required this.customerId,
    required this.customerName,
    required this.startInclusive,
    required this.endExclusive,
    required this.openingBalance,
    required this.entries,
  });

  Money get closingBalance =>
      entries.fold(openingBalance, (balance, entry) => balance + entry.amount);
}

class CashReceivedRow {
  final DateTime paymentDate;
  final int paymentId;
  final int? invoiceId;
  final String customerName;
  final String? paymentMethod;
  final String? reference;
  final Money amount;

  const CashReceivedRow({
    required this.paymentDate,
    required this.paymentId,
    required this.invoiceId,
    required this.customerName,
    required this.paymentMethod,
    required this.reference,
    required this.amount,
  });
}

class CashReceivedReport {
  final AccountingPeriod period;
  final List<CashReceivedRow> rows;

  const CashReceivedReport({required this.period, required this.rows});

  Money get total =>
      rows.fold(MoneyEx.zero, (total, row) => total + row.amount);
}

class TaxSummaryReport {
  final AccountingPeriod period;
  final String taxLabel;
  final Money taxCollected;
  final Money creditTax;
  final Money supplierTaxPaid;
  final bool taxCollectedIsEstimated;

  const TaxSummaryReport({
    required this.period,
    required this.taxLabel,
    required this.taxCollected,
    required this.creditTax,
    required this.supplierTaxPaid,
    required this.taxCollectedIsEstimated,
  });

  Money get netTaxCollected => taxCollected - creditTax;

  Money get netTaxPosition => netTaxCollected - supplierTaxPaid;
}

class SupplierSpendRow {
  final int supplierId;
  final String supplierName;
  final Money excludingTax;
  final Money tax;
  final Money includingTax;
  final int receiptCount;

  const SupplierSpendRow({
    required this.supplierId,
    required this.supplierName,
    required this.excludingTax,
    required this.tax,
    required this.includingTax,
    required this.receiptCount,
  });
}

class SupplierSpendReport {
  final AccountingPeriod period;
  final List<SupplierSpendRow> rows;

  const SupplierSpendReport({required this.period, required this.rows});

  Money get totalExcludingTax =>
      rows.fold(MoneyEx.zero, (total, row) => total + row.excludingTax);

  Money get totalTax =>
      rows.fold(MoneyEx.zero, (total, row) => total + row.tax);

  Money get totalIncludingTax =>
      rows.fold(MoneyEx.zero, (total, row) => total + row.includingTax);
}

class UnlinkedCostRow {
  final int receiptId;
  final DateTime receiptDate;
  final String supplierName;
  final String jobSummary;
  final Money amount;

  const UnlinkedCostRow({
    required this.receiptId,
    required this.receiptDate,
    required this.supplierName,
    required this.jobSummary,
    required this.amount,
  });
}

class UnlinkedCostReport {
  final List<UnlinkedCostRow> rows;

  const UnlinkedCostReport({required this.rows});

  Money get total =>
      rows.fold(MoneyEx.zero, (total, row) => total + row.amount);
}

class _StatementInvoice {
  final Invoice invoice;
  final String customerName;

  const _StatementInvoice({required this.invoice, required this.customerName});
}

class AccountingReportService {
  Future<ProfitAndLossReport> profitAndLoss(AccountingPeriod period) async {
    final invoiceIncome = await _invoiceIncome(period: period);
    final creditNotes = await _creditNotes(period: period);
    final debtorAdjustments = await _debtorAdjustments(period: period);
    final receiptExpenses = await _receiptExpenses(period: period);

    return ProfitAndLossReport(
      period: period,
      invoiceIncome: invoiceIncome,
      creditNotes: creditNotes,
      debtorAdjustments: debtorAdjustments,
      receiptExpenses: receiptExpenses,
    );
  }

  Future<ProfitAndLossReport> profitAndLossForMonth(DateTime date) =>
      profitAndLoss(AccountingPeriod.forMonth(date));

  Future<ProfitAndLossReport> profitAndLossForQuarter(DateTime date) =>
      profitAndLoss(AccountingPeriod.forQuarter(date));

  Future<ProfitAndLossReport> profitAndLossForYear(DateTime date) =>
      profitAndLoss(AccountingPeriod.forYear(date));

  Future<JobProfitReport> jobProfit(int jobId) async {
    final invoiceIncome = await _invoiceIncome(jobId: jobId);
    final creditNotes = await _creditNotes(jobId: jobId);
    final debtorAdjustments = await _debtorAdjustments(jobId: jobId);
    final receiptExpenses = await _receiptExpenses(jobId: jobId);
    final unreceiptedActualCosts = await _unreceiptedActualCosts(jobId);

    return JobProfitReport(
      jobId: jobId,
      invoiceIncome: invoiceIncome,
      creditNotes: creditNotes,
      debtorAdjustments: debtorAdjustments,
      receiptExpenses: receiptExpenses,
      unreceiptedActualCosts: unreceiptedActualCosts,
    );
  }

  Future<AgedReceivablesReport> agedReceivables({LocalDate? asOfDate}) async {
    final asOf = asOfDate ?? LocalDate.today();
    final db = DaoInvoice().withoutTransaction();
    final data = await db.rawQuery(
      '''
WITH invoice_balances AS (
  SELECT
    i.id AS invoice_id,
    i.due_date,
    c.id AS customer_id,
    IFNULL(c.name, 'Unknown customer') AS customer_name,
    (
      i.total_amount
      - IFNULL(pa.paid, 0)
      - IFNULL(ca.credited, 0)
      - IFNULL(da.adjusted, 0)
    ) AS balance
  FROM invoice i
  LEFT JOIN job j ON j.id = i.job_id
  LEFT JOIN customer c ON c.id = j.customer_id
  LEFT JOIN (
    SELECT invoice_id, SUM(amount) AS paid
    FROM debtor_payment_allocation
    GROUP BY invoice_id
  ) pa ON pa.invoice_id = i.id
  LEFT JOIN (
    SELECT invoice_id, SUM(amount) AS credited
    FROM credit_allocation
    GROUP BY invoice_id
  ) ca ON ca.invoice_id = i.id
  LEFT JOIN (
    SELECT invoice_id, SUM(amount) AS adjusted
    FROM debtor_adjustment
    GROUP BY invoice_id
  ) da ON da.invoice_id = i.id
  WHERE IFNULL(i.paid, 0) = 0
    AND IFNULL(i.external_sync_status, 0) NOT IN (?, ?)
)
SELECT *
FROM invoice_balances
WHERE balance > 0
ORDER BY due_date ASC, invoice_id ASC
''',
      [
        InvoiceExternalSyncStatus.deleted.ordinal,
        InvoiceExternalSyncStatus.voided.ordinal,
      ],
    );

    final rows = [
      for (final row in data) _agedReceivablesRow(row: row, asOf: asOf),
    ];

    return AgedReceivablesReport(
      asOfDate: asOf,
      rows: rows,
      buckets: _agedReceivablesBuckets(rows),
    );
  }

  AgedReceivablesRow _agedReceivablesRow({
    required Map<String, Object?> row,
    required LocalDate asOf,
  }) {
    final dueDateValue = row['due_date'] as String?;
    final dueDate = dueDateValue == null
        ? asOf
        : const LocalDateConverter().fromJson(dueDateValue);
    return AgedReceivablesRow(
      invoiceId: row['invoice_id']! as int,
      customerId: row['customer_id'] as int?,
      customerName: (row['customer_name'] as String?) ?? 'Unknown customer',
      dueDate: dueDate,
      balance: MoneyEx.fromInt(row['balance'] as int? ?? 0),
      daysOverdue: asOf.difference(dueDate).inDays,
    );
  }

  Future<DebtorStatementReport> debtorStatement({
    required int? customerId,
    required DateTime startInclusive,
    required DateTime endExclusive,
    int? jobId,
  }) async {
    final invoices = await _statementInvoicesForCustomer(
      customerId,
      jobId: jobId,
    );
    final histories = await _statementHistoryForInvoices(
      invoices.map((invoice) => invoice.invoice.id).toList(),
    );
    final externalAccountingEnabled = await ExternalAccounting().isEnabled();
    var openingBalance = MoneyEx.zero;
    final entries = <DebtorStatementEntry>[];

    for (final statementInvoice in invoices) {
      final invoice = statementInvoice.invoice;
      if (invoice.isExternallyDeletedOrVoided) {
        continue;
      }
      final invoiceNumber = invoice.displayNumber(
        externalAccountingEnabled: externalAccountingEnabled,
      );
      final customerName = statementInvoice.customerName;

      if (invoice.createdDate.isBefore(startInclusive)) {
        openingBalance += invoice.totalAmount;
      } else if (invoice.createdDate.isBefore(endExclusive)) {
        entries.add(
          DebtorStatementEntry(
            type: DebtorStatementEntryType.invoice,
            invoiceId: invoice.id,
            invoiceNumber: invoiceNumber,
            customerName: customerName,
            date: invoice.createdDate,
            description: 'Invoice issued',
            amount: invoice.totalAmount,
          ),
        );
      }

      final historyEntries = histories[invoice.id] ?? const [];
      if (invoice.paid && historyEntries.isEmpty) {
        _addPaidInvoiceEntry(
          entries: entries,
          invoice: invoice,
          invoiceNumber: invoiceNumber,
          customerName: customerName,
          openingBalance: (amount) => openingBalance += amount,
          startInclusive: startInclusive,
          endExclusive: endExclusive,
        );
      }

      for (final history in historyEntries) {
        final amount = -history.amount;
        if (history.date.isBefore(startInclusive)) {
          openingBalance += amount;
        } else if (history.date.isBefore(endExclusive)) {
          entries.add(
            DebtorStatementEntry(
              type: _statementEntryType(history.type),
              invoiceId: invoice.id,
              invoiceNumber: invoiceNumber,
              customerName: customerName,
              date: history.date,
              description: history.title,
              amount: amount,
            ),
          );
        }
      }
    }

    entries.sort((lhs, rhs) {
      final date = lhs.date.compareTo(rhs.date);
      return date == 0 ? lhs.invoiceId.compareTo(rhs.invoiceId) : date;
    });

    return DebtorStatementReport(
      customerId: customerId,
      customerName: await _statementName(customerId: customerId, jobId: jobId),
      startInclusive: startInclusive,
      endExclusive: endExclusive,
      openingBalance: openingBalance,
      entries: entries,
    );
  }

  void _addPaidInvoiceEntry({
    required List<DebtorStatementEntry> entries,
    required Invoice invoice,
    required String invoiceNumber,
    required String customerName,
    required void Function(Money amount) openingBalance,
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    final paymentDate = invoice.paidDate ?? invoice.modifiedDate;
    final amount = -invoice.totalAmount;
    if (paymentDate.isBefore(startInclusive)) {
      openingBalance(amount);
      return;
    }
    if (!paymentDate.isBefore(endExclusive)) {
      return;
    }
    entries.add(
      DebtorStatementEntry(
        type: DebtorStatementEntryType.payment,
        invoiceId: invoice.id,
        invoiceNumber: invoiceNumber,
        customerName: customerName,
        date: paymentDate,
        description: 'Payment received',
        amount: amount,
      ),
    );
  }

  Future<CashReceivedReport> cashReceived(AccountingPeriod period) async {
    final db = DaoInvoice().withoutTransaction();
    final rows = await db.rawQuery('''
SELECT
  p.id AS payment_id,
  p.payment_date,
  p.payment_method,
  p.reference,
  pa.invoice_id,
  IFNULL(pa.amount, p.amount) AS amount,
  c.name AS customer_name,
  pc.name AS payment_customer_name
FROM debtor_payment p
LEFT JOIN debtor_payment_allocation pa ON pa.payment_id = p.id
LEFT JOIN invoice i ON i.id = pa.invoice_id
LEFT JOIN job j ON j.id = i.job_id
LEFT JOIN customer c ON c.id = j.customer_id
LEFT JOIN customer pc ON pc.id = p.customer_id
WHERE p.payment_date >= ? AND p.payment_date < ?
ORDER BY p.payment_date, p.id, pa.invoice_id
''', _periodArgs(period));

    return CashReceivedReport(
      period: period,
      rows: [
        for (final row in rows)
          CashReceivedRow(
            paymentDate: DateTime.parse(row['payment_date']! as String),
            paymentId: row['payment_id']! as int,
            invoiceId: row['invoice_id'] as int?,
            customerName:
                (row['customer_name'] ?? row['payment_customer_name'])
                    as String? ??
                'Unknown customer',
            paymentMethod: row['payment_method'] as String?,
            reference: row['reference'] as String?,
            amount: MoneyEx.fromInt(row['amount']! as int),
          ),
      ],
    );
  }

  Future<TaxSummaryReport> taxSummary(AccountingPeriod period) async {
    final explicitInvoiceTax = await _invoiceTax(period: period);
    final explicitCreditTax = await _creditNoteTax(period: period);
    final hasExplicitTax =
        explicitInvoiceTax.isNonZero || explicitCreditTax.isNonZero;
    final invoiceTax = hasExplicitTax
        ? explicitInvoiceTax
        : await _derivedTaxFrom(source: _invoiceIncome(period: period));
    final creditTax = hasExplicitTax
        ? explicitCreditTax
        : await _derivedTaxFrom(source: _creditNotes(period: period));
    final supplierTaxPaid = await _receiptTax(period: period);
    final taxConfig = await _taxConfig();

    return TaxSummaryReport(
      period: period,
      taxLabel: taxConfig.label,
      taxCollected: invoiceTax,
      creditTax: creditTax,
      supplierTaxPaid: supplierTaxPaid,
      taxCollectedIsEstimated:
          !hasExplicitTax && taxConfig.mode == TaxDisplayMode.inclusive,
    );
  }

  Future<SupplierSpendReport> supplierSpend(AccountingPeriod period) async {
    final db = DaoInvoice().withoutTransaction();
    final rows = await db.rawQuery('''
SELECT
  s.id AS supplier_id,
  s.name AS supplier_name,
  COUNT(r.id) AS receipt_count,
  IFNULL(SUM(r.total_excluding_tax), 0) AS excluding_tax,
  IFNULL(SUM(r.tax), 0) AS tax,
  IFNULL(SUM(r.total_including_tax), 0) AS including_tax
FROM receipt r
JOIN supplier s ON s.id = r.supplier_id
WHERE r.receipt_date >= ? AND r.receipt_date < ?
GROUP BY s.id, s.name
ORDER BY including_tax DESC, s.name
''', _periodArgs(period));

    return SupplierSpendReport(
      period: period,
      rows: [
        for (final row in rows)
          SupplierSpendRow(
            supplierId: row['supplier_id']! as int,
            supplierName: row['supplier_name']! as String,
            receiptCount: row['receipt_count']! as int,
            excludingTax: MoneyEx.fromInt(row['excluding_tax']! as int),
            tax: MoneyEx.fromInt(row['tax']! as int),
            includingTax: MoneyEx.fromInt(row['including_tax']! as int),
          ),
      ],
    );
  }

  Future<UnlinkedCostReport> unlinkedCosts() async {
    final db = DaoInvoice().withoutTransaction();
    final rows = await db.rawQuery('''
SELECT
  r.id AS receipt_id,
  r.receipt_date,
  r.total_excluding_tax,
  s.name AS supplier_name,
  IFNULL(j.summary, 'Unknown job') AS job_summary
FROM receipt r
JOIN supplier s ON s.id = r.supplier_id
LEFT JOIN job j ON j.id = r.job_id
WHERE NOT EXISTS (
  SELECT 1
  FROM receipt_task_item rti
  WHERE rti.receipt_id = r.id
)
AND EXISTS (
  SELECT 1
  FROM receipt_job_allocation rja
  WHERE rja.receipt_id = r.id
)
ORDER BY r.receipt_date DESC, r.id DESC
''');

    return UnlinkedCostReport(
      rows: [
        for (final row in rows)
          UnlinkedCostRow(
            receiptId: row['receipt_id']! as int,
            receiptDate: DateTime.parse(row['receipt_date']! as String),
            supplierName: row['supplier_name']! as String,
            jobSummary: row['job_summary']! as String,
            amount: MoneyEx.fromInt(row['total_excluding_tax']! as int),
          ),
      ],
    );
  }

  Future<Money> _invoiceIncome({AccountingPeriod? period, int? jobId}) => _sum(
    '''
SELECT IFNULL(SUM(total_amount), 0) AS total
FROM invoice
WHERE IFNULL(external_sync_status, ?) NOT IN (?, ?)
${_periodClause(period, 'created_date')}
${_jobClause(jobId, 'job_id')}
''',
    [
      InvoiceExternalSyncStatus.none.ordinal,
      InvoiceExternalSyncStatus.deleted.ordinal,
      InvoiceExternalSyncStatus.voided.ordinal,
      ..._periodArgs(period),
      ..._jobArgs(jobId),
    ],
  );

  Future<List<_StatementInvoice>> _statementInvoicesForCustomer(
    int? customerId, {
    int? jobId,
  }) async {
    final where = <String>['1 = 1'];
    final args = <Object?>[];
    if (jobId != null) {
      where.add('i.job_id = ?');
      args.add(jobId);
    } else if (customerId != null) {
      where.add('j.customer_id = ?');
      args.add(customerId);
    }
    final db = DaoInvoice().withoutTransaction();
    final rows = await db.rawQuery('''
SELECT i.*, IFNULL(c.name, 'Unknown customer') AS statement_customer_name
FROM invoice i
LEFT JOIN job j ON j.id = i.job_id
LEFT JOIN customer c ON c.id = j.customer_id
WHERE ${where.join(' AND ')}
ORDER BY i.created_date ASC, i.id ASC
''', args);

    return [
      for (final row in rows)
        _StatementInvoice(
          invoice: Invoice.fromMap(row),
          customerName: row['statement_customer_name']! as String,
        ),
    ];
  }

  Future<String> _customerName(int? customerId) async {
    if (customerId == null) {
      return 'All customers';
    }
    return (await DaoCustomer().getById(customerId))?.name ??
        'Customer #$customerId';
  }

  Future<Map<int, List<InvoiceLedgerHistoryEntry>>>
  _statementHistoryForInvoices(List<int> invoiceIds) async {
    if (invoiceIds.isEmpty) {
      return const {};
    }
    final db = DaoInvoice().withoutTransaction();
    final placeholders = List.filled(invoiceIds.length, '?').join(', ');
    final histories = <int, List<InvoiceLedgerHistoryEntry>>{};
    void add(int invoiceId, InvoiceLedgerHistoryEntry entry) {
      histories.putIfAbsent(invoiceId, () => []).add(entry);
    }

    final payments = await db.rawQuery('''
SELECT
  pa.invoice_id,
  pa.allocated_date,
  pa.amount,
  p.payment_method,
  p.reference,
  p.notes
FROM debtor_payment_allocation pa
LEFT JOIN debtor_payment p ON p.id = pa.payment_id
WHERE pa.invoice_id IN ($placeholders)
ORDER BY pa.allocated_date ASC, pa.id ASC
''', invoiceIds);
    for (final row in payments) {
      add(
        row['invoice_id']! as int,
        InvoiceLedgerHistoryEntry(
          type: InvoiceLedgerHistoryEntryType.payment,
          date: DateTime.parse(row['allocated_date']! as String),
          amount: MoneyEx.fromInt(row['amount']! as int),
          title: 'Payment received',
          detail: _paymentDetail(row),
        ),
      );
    }

    final credits = await db.rawQuery('''
SELECT
  ca.invoice_id,
  ca.allocated_date,
  ca.amount,
  cn.reason
FROM credit_allocation ca
LEFT JOIN credit_note cn ON cn.id = ca.credit_note_id
WHERE ca.invoice_id IN ($placeholders)
ORDER BY ca.allocated_date ASC, ca.id ASC
''', invoiceIds);
    for (final row in credits) {
      add(
        row['invoice_id']! as int,
        InvoiceLedgerHistoryEntry(
          type: InvoiceLedgerHistoryEntryType.credit,
          date: DateTime.parse(row['allocated_date']! as String),
          amount: MoneyEx.fromInt(row['amount']! as int),
          title: 'Credit applied',
          detail: row['reason'] as String?,
        ),
      );
    }

    final adjustments = await db.rawQuery('''
SELECT
  invoice_id,
  adjustment_date,
  amount,
  adjustment_type,
  reason
FROM debtor_adjustment
WHERE invoice_id IN ($placeholders)
ORDER BY adjustment_date ASC, id ASC
''', invoiceIds);
    for (final row in adjustments) {
      final type = DebtorAdjustmentType.fromOrdinal(
        row['adjustment_type'] as int?,
      );
      add(
        row['invoice_id']! as int,
        InvoiceLedgerHistoryEntry(
          type: InvoiceLedgerHistoryEntryType.adjustment,
          date: DateTime.parse(row['adjustment_date']! as String),
          amount: MoneyEx.fromInt(row['amount']! as int),
          title: _adjustmentTitle(type),
          detail: row['reason'] as String?,
        ),
      );
    }

    for (final entries in histories.values) {
      entries.sort((lhs, rhs) => lhs.date.compareTo(rhs.date));
    }
    return histories;
  }

  Future<String> _statementName({int? customerId, int? jobId}) async {
    if (jobId != null) {
      return (await DaoJob().getById(jobId))?.summary ?? 'Job #$jobId';
    }
    return _customerName(customerId);
  }

  String? _paymentDetail(Map<String, Object?> row) {
    final parts = [
      row['payment_method'] as String?,
      row['reference'] as String?,
      row['notes'] as String?,
    ].nonNulls.map((part) => part.trim()).where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' - ');
  }

  String _adjustmentTitle(DebtorAdjustmentType type) => switch (type) {
    DebtorAdjustmentType.rounding => 'Rounding adjustment',
    DebtorAdjustmentType.writeOff => 'Write-off',
    DebtorAdjustmentType.badDebt => 'Bad debt write-off',
    DebtorAdjustmentType.correction => 'Adjustment',
    DebtorAdjustmentType.openingBalance => 'Opening balance',
    DebtorAdjustmentType.other => 'Adjustment',
  };

  DebtorStatementEntryType _statementEntryType(
    InvoiceLedgerHistoryEntryType type,
  ) => switch (type) {
    InvoiceLedgerHistoryEntryType.payment => DebtorStatementEntryType.payment,
    InvoiceLedgerHistoryEntryType.credit => DebtorStatementEntryType.credit,
    InvoiceLedgerHistoryEntryType.adjustment =>
      DebtorStatementEntryType.adjustment,
  };

  Future<Money> _creditNotes({AccountingPeriod? period, int? jobId}) => _sum(
    '''
SELECT IFNULL(SUM(total_amount), 0) AS total
FROM credit_note
WHERE status IN (?, ?, ?)
${_periodClause(period, 'credit_date')}
${_jobClause(jobId, 'job_id')}
''',
    [
      CreditNoteStatus.approved.ordinal,
      CreditNoteStatus.partiallyAllocated.ordinal,
      CreditNoteStatus.allocated.ordinal,
      ..._periodArgs(period),
      ..._jobArgs(jobId),
    ],
  );

  Future<Money> _debtorAdjustments({AccountingPeriod? period, int? jobId}) =>
      _sum(
        '''
SELECT IFNULL(SUM(amount), 0) AS total
FROM debtor_adjustment
WHERE 1 = 1
${_periodClause(period, 'adjustment_date')}
${_jobClause(jobId, 'job_id')}
''',
        [..._periodArgs(period), ..._jobArgs(jobId)],
      );

  Future<Money> _receiptExpenses({AccountingPeriod? period, int? jobId}) =>
      _sum(
        jobId == null
            ? '''
SELECT IFNULL(SUM(total_excluding_tax), 0) AS total
FROM receipt
WHERE 1 = 1
${_periodClause(period, 'receipt_date')}
'''
            : '''
SELECT IFNULL(SUM(rja.amount), 0) AS total
FROM receipt_job_allocation rja
JOIN receipt r ON r.id = rja.receipt_id
WHERE rja.job_id = ?
${_periodClause(period, 'r.receipt_date')}
''',
        jobId == null ? _periodArgs(period) : [jobId, ..._periodArgs(period)],
      );

  Future<Money> _receiptTax({AccountingPeriod? period}) => _sum('''
SELECT IFNULL(SUM(tax), 0) AS total
FROM receipt
WHERE 1 = 1
${_periodClause(period, 'receipt_date')}
''', _periodArgs(period));

  Future<Money> _invoiceTax({AccountingPeriod? period}) => _sum(
    '''
SELECT IFNULL(SUM(il.tax_amount), 0) AS total
FROM invoice_line il
JOIN invoice i ON i.id = il.invoice_id
WHERE IFNULL(i.external_sync_status, ?) NOT IN (?, ?)
${_periodClause(period, 'i.created_date')}
''',
    [
      InvoiceExternalSyncStatus.none.ordinal,
      InvoiceExternalSyncStatus.deleted.ordinal,
      InvoiceExternalSyncStatus.voided.ordinal,
      ..._periodArgs(period),
    ],
  );

  Future<Money> _creditNoteTax({AccountingPeriod? period}) => _sum(
    '''
SELECT IFNULL(SUM(cnl.tax_amount), 0) AS total
FROM credit_note_line cnl
JOIN credit_note cn ON cn.id = cnl.credit_note_id
WHERE cn.status IN (?, ?, ?)
${_periodClause(period, 'cn.credit_date')}
''',
    [
      CreditNoteStatus.approved.ordinal,
      CreditNoteStatus.partiallyAllocated.ordinal,
      CreditNoteStatus.allocated.ordinal,
      ..._periodArgs(period),
    ],
  );

  Future<Money> _unreceiptedActualCosts(int jobId) => _sum(
    '''
SELECT IFNULL(
  SUM(
    CAST(
      ROUND(ti.actual_unit_cost * ti.actual_quantity / 1000.0)
      AS INTEGER
    )
  ),
  0
) AS total
FROM task_item ti
JOIN task t ON t.id = ti.task_id
WHERE t.job_id = ?
AND ti.actual_unit_cost IS NOT NULL
AND ti.actual_quantity IS NOT NULL
AND NOT EXISTS (
  SELECT 1
  FROM receipt_task_item rti
  WHERE rti.task_item_id = ti.id
)
''',
    [jobId],
  );

  AgedReceivablesBucket _agedReceivablesBuckets(List<AgedReceivablesRow> rows) {
    var current = MoneyEx.zero;
    var oneToThirty = MoneyEx.zero;
    var thirtyOneToSixty = MoneyEx.zero;
    var sixtyOneToNinety = MoneyEx.zero;
    var overNinety = MoneyEx.zero;

    for (final row in rows) {
      if (row.daysOverdue <= 0) {
        current += row.balance;
      } else if (row.daysOverdue <= 30) {
        oneToThirty += row.balance;
      } else if (row.daysOverdue <= 60) {
        thirtyOneToSixty += row.balance;
      } else if (row.daysOverdue <= 90) {
        sixtyOneToNinety += row.balance;
      } else {
        overNinety += row.balance;
      }
    }

    return AgedReceivablesBucket(
      current: current,
      oneToThirty: oneToThirty,
      thirtyOneToSixty: thirtyOneToSixty,
      sixtyOneToNinety: sixtyOneToNinety,
      overNinety: overNinety,
    );
  }

  Future<Money> _sum(String sql, List<Object?> args) async {
    final db = DaoInvoice().withoutTransaction();
    final rows = await db.rawQuery(sql, args);
    return MoneyEx.fromInt(rows.first['total'] as int? ?? 0);
  }

  Future<Money> _derivedTaxFrom({required Future<Money> source}) async {
    final amount = await source;
    final config = await _taxConfig();
    if (config.mode != TaxDisplayMode.inclusive || config.ratePercent <= 0) {
      return MoneyEx.zero;
    }
    final tax = amount.minorUnits.toInt() * config.ratePercent;
    return MoneyEx.fromInt((tax / (100 + config.ratePercent)).round());
  }

  Future<_TaxConfig> _taxConfig() async {
    final scheme = await _selectedTaxScheme();
    final defaultSalesCode = scheme == null
        ? null
        : await DaoTaxCode().getDefaultSalesCode(scheme.id);
    final configuredLabel = (await AppSettings.getTaxLabel()).trim();
    final configuredRate = double.tryParse(
      (await AppSettings.getTaxRatePercentText()).trim(),
    );
    return _TaxConfig(
      label: configuredLabel.isEmpty
          ? scheme?.taxLabel ?? 'Tax'
          : configuredLabel,
      ratePercent: configuredRate ?? _ratePercent(defaultSalesCode) ?? 0,
      mode: await AppSettings.getTaxDisplayMode(),
    );
  }

  Future<TaxScheme?> _selectedTaxScheme() async {
    final schemeCode = await AppSettings.getTaxSchemeCode();
    if (schemeCode.isNotEmpty) {
      final scheme = await DaoTaxScheme().getByCode(schemeCode);
      if (scheme != null) {
        return scheme;
      }
    }

    final countryCode = (await DaoSystem().get()).countryCode?.trim();
    if (countryCode != null && countryCode.isNotEmpty) {
      final scheme = await DaoTaxScheme().getByCountryCode(countryCode);
      if (scheme != null) {
        return scheme;
      }
    }

    return DaoTaxScheme().getByCode('custom');
  }

  double? _ratePercent(TaxCode? code) =>
      code == null ? null : code.rateBasisPoints / 100;

  String _periodClause(AccountingPeriod? period, String column) =>
      period == null ? '' : 'AND $column >= ? AND $column < ?';

  List<Object?> _periodArgs(AccountingPeriod? period) => period == null
      ? const []
      : [
          period.startInclusive.toIso8601String(),
          period.endExclusive.toIso8601String(),
        ];

  String _jobClause(int? jobId, String column) =>
      jobId == null ? '' : 'AND $column = ?';

  List<Object?> _jobArgs(int? jobId) => jobId == null ? const [] : [jobId];
}

class _TaxConfig {
  final String label;
  final double ratePercent;
  final TaxDisplayMode mode;

  const _TaxConfig({
    required this.label,
    required this.ratePercent,
    required this.mode,
  });
}

class AccountingReportCsvExporter {
  String profitAndLoss(ProfitAndLossReport report) => _csv([
    ['Line', 'Amount'],
    ['Invoice income', report.invoiceIncome],
    ['Credits', -report.creditNotes],
    ['Adjustments', -report.debtorAdjustments],
    ['Net income', report.netIncome],
    ['Supplier receipts', -report.receiptExpenses],
    ['Net profit', report.netProfit],
  ]);

  String jobProfit(JobProfitReport report) => _csv([
    ['Line', 'Amount'],
    ['Invoice income', report.invoiceIncome],
    ['Credits', -report.creditNotes],
    ['Adjustments', -report.debtorAdjustments],
    ['Net income', report.netIncome],
    ['Supplier receipts', -report.receiptExpenses],
    ['Unreceipted actual costs', -report.unreceiptedActualCosts],
    ['Net profit', report.netProfit],
  ]);

  String agedReceivables(AgedReceivablesReport report) => _csv([
    ['Invoice', 'Customer', 'Due date', 'Days overdue', 'Balance'],
    for (final row in report.rows)
      [
        row.invoiceId,
        row.customerName,
        row.dueDate.toIso8601String(),
        row.daysOverdue,
        row.balance,
      ],
  ]);

  String debtorStatement(DebtorStatementReport report) => _csv([
    ['Customer', report.customerName],
    ['Period', _statementPeriod(report)],
    [],
    if (report.customerId == null)
      ['Date', 'Invoice', 'Customer', 'Description', 'Amount', 'Balance']
    else
      ['Date', 'Invoice', 'Description', 'Amount', 'Balance'],
    ..._debtorStatementCsvRows(report),
  ]);

  String _statementPeriod(DebtorStatementReport report) {
    final endInclusive = report.endExclusive.subtract(const Duration(days: 1));
    return '${report.startInclusive.toIso8601String()} to '
        '${endInclusive.toIso8601String()}';
  }

  List<List<Object?>> _debtorStatementCsvRows(DebtorStatementReport report) {
    var balance = report.openingBalance;
    final rows = <List<Object?>>[];
    if (report.customerId == null) {
      rows.add(['', '', '', 'Opening balance', '', balance]);
      for (final entry in report.entries) {
        balance += entry.amount;
        rows.add([
          entry.date.toIso8601String(),
          entry.invoiceNumber,
          entry.customerName,
          entry.description,
          entry.amount,
          balance,
        ]);
      }
      rows.add(['', '', '', 'Closing balance', '', balance]);
    } else {
      rows.add(['', '', 'Opening balance', '', balance]);
      for (final entry in report.entries) {
        balance += entry.amount;
        rows.add([
          entry.date.toIso8601String(),
          entry.invoiceNumber,
          entry.description,
          entry.amount,
          balance,
        ]);
      }
      rows.add(['', '', 'Closing balance', '', balance]);
    }
    return rows;
  }

  String cashReceived(CashReceivedReport report) => _csv([
    ['Date', 'Payment', 'Invoice', 'Customer', 'Method', 'Reference', 'Amount'],
    for (final row in report.rows)
      [
        row.paymentDate.toIso8601String(),
        row.paymentId,
        row.invoiceId,
        row.customerName,
        row.paymentMethod,
        row.reference,
        row.amount,
      ],
  ]);

  String taxSummary(TaxSummaryReport report) => _csv([
    ['Line', 'Amount'],
    ['${report.taxLabel} collected from invoices', report.taxCollected],
    ['${report.taxLabel} credited', -report.creditTax],
    ['Net ${report.taxLabel} collected', report.netTaxCollected],
    ['${report.taxLabel} paid on receipts', -report.supplierTaxPaid],
    ['Net ${report.taxLabel} position', report.netTaxPosition],
    if (report.taxCollectedIsEstimated)
      ['Invoice ${report.taxLabel} values estimated', 'Yes'],
    if (!report.taxCollectedIsEstimated)
      ['Invoice ${report.taxLabel} values estimated', 'No'],
  ]);

  String supplierSpend(SupplierSpendReport report) => _csv([
    ['Supplier', 'Receipts', 'Excluding tax', 'Tax', 'Including tax'],
    for (final row in report.rows)
      [
        row.supplierName,
        row.receiptCount,
        row.excludingTax,
        row.tax,
        row.includingTax,
      ],
  ]);

  String unlinkedCosts(UnlinkedCostReport report) => _csv([
    ['Receipt', 'Date', 'Supplier', 'Job', 'Amount'],
    for (final row in report.rows)
      [
        row.receiptId,
        row.receiptDate.toIso8601String(),
        row.supplierName,
        row.jobSummary,
        row.amount,
      ],
  ]);

  String _csv(List<List<Object?>> rows) =>
      rows.map((row) => row.map(_cell).join(',')).join('\n');

  String _cell(Object? value) {
    final text = value?.toString() ?? '';
    final escaped = text.replaceAll('"', '""');
    return escaped.contains(',') ||
            escaped.contains('"') ||
            escaped.contains('\n')
        ? '"$escaped"'
        : escaped;
  }
}

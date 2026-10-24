// ignore_for_file: async_return_with_no_await

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
import 'package:sqflite_common/sqlite_api.dart';

import '../api/external_accounting.dart';
import '../entity/credit_note.dart';
import '../entity/debtor_adjustment.dart';
import '../entity/helpers/charge_mode.dart';
import '../entity/invoice.dart';
import '../entity/job.dart';
import '../entity/job_status.dart';
import '../entity/task_item.dart';
import '../entity/task_item_type.dart';
import '../util/dart/app_settings.dart';
import '../util/dart/local_date.dart';
import '../util/dart/money_ex.dart';
import 'dao_customer.dart';
import 'dao_invoice.dart';
import 'dao_job.dart';
import 'dao_system.dart';
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
  final int unknownTaxDocuments;

  const TaxSummaryReport({
    required this.period,
    required this.taxLabel,
    required this.taxCollected,
    required this.creditTax,
    required this.supplierTaxPaid,
    required this.taxCollectedIsEstimated,
    this.unknownTaxDocuments = 0,
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

class MaterialBillingRow {
  final TaskItem taskItem;
  final int jobId;
  final String jobSummary;
  final String customerName;
  final String taskName;
  final BillingType billingType;
  final Money hourlyRate;
  final int? invoiceId;
  final String? invoiceNumber;

  const MaterialBillingRow({
    required this.taskItem,
    required this.jobId,
    required this.jobSummary,
    required this.customerName,
    required this.taskName,
    required this.billingType,
    required this.hourlyRate,
    required this.invoiceId,
    required this.invoiceNumber,
  });

  bool get hasActualPrice => taskItem.actualPrice != null;

  /// An explicit zero charge (or an actual zero-priced item) is not missing
  /// billing. An unpriced estimate must still be reviewed.
  bool get noCharge =>
      charge.isZero &&
      (hasActualPrice ||
          taskItem.chargeMode == ChargeMode.userDefined ||
          billingType == BillingType.nonBillable);
  bool get needsBilling => !taskItem.billed && !noCharge;
  bool get missingPrice => !hasActualPrice && !noCharge;
  String get billingStatus => taskItem.billed
      ? 'Billed'
      : noCharge
      ? 'No charge'
      : 'Not billed';

  Money? get actualCost {
    final total = taskItem.actualPrice?.totalCost;
    if (total == null) {
      return null;
    }
    return taskItem.isReturn ? -total : total;
  }

  Money get charge => taskItem.getTotalLineCharge(billingType, hourlyRate);

  String get invoiceDisplay => invoiceNumber?.trim().isNotEmpty ?? false
      ? invoiceNumber!.trim()
      : invoiceId == null
      ? ''
      : '#$invoiceId';
}

class MaterialBillingReport {
  final List<MaterialBillingRow> rows;

  const MaterialBillingReport({required this.rows});

  int get unbilledCount => rows.where((row) => row.needsBilling).length;

  int get missingPriceCount => rows.where((row) => row.missingPrice).length;

  int get noChargeCount => rows.where((row) => row.noCharge).length;

  int get billedCount => rows.where((row) => row.taskItem.billed).length;
}

class _StatementInvoice {
  final Invoice invoice;
  final String customerName;
  final DateTime issuedDate;
  final DateTime? voidedDate;

  const _StatementInvoice({
    required this.invoice,
    required this.customerName,
    required this.issuedDate,
    this.voidedDate,
  });
}

class _StatementPayment {
  final DateTime paymentDate;
  final Money amount;
  final String customerName;

  const _StatementPayment({
    required this.paymentDate,
    required this.amount,
    required this.customerName,
  });
}

class AccountingReportService {
  final DatabaseExecutor? snapshot;
  final String? taxLabel;
  final bool? externalAccountingEnabled;

  AccountingReportService({
    this.snapshot,
    this.taxLabel,
    this.externalAccountingEnabled,
  });

  DatabaseExecutor get _db => snapshot ?? DaoInvoice().withoutTransaction();

  static Future<String> resolveTaxLabel() async {
    final label = (await AppSettings.getTaxLabel()).trim();
    if (label.isNotEmpty) {
      return label;
    }
    final scheme = await DaoTaxScheme().getByCode(
      await AppSettings.getTaxSchemeCode(),
    );
    if (scheme != null) {
      return scheme.taxLabel;
    }
    final country = (await DaoSystem().get()).countryCode;
    return country == null
        ? 'Tax'
        : (await DaoTaxScheme().getByCountryCode(country))?.taxLabel ?? 'Tax';
  }

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
    final cutoff = asOf
        .add(const Duration(days: 1))
        .toDateTime()
        .toIso8601String();
    final db = _db;
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
  LEFT JOIN customer c ON c.id = COALESCE(i.billing_customer_id, j.bill_to_customer_id, j.customer_id)
  LEFT JOIN (
    SELECT a.invoice_id, SUM(a.amount) AS paid
    FROM debtor_payment_allocation a JOIN debtor_payment p ON p.id = a.payment_id
    WHERE a.allocated_date < ? AND p.payment_date < ?
    GROUP BY a.invoice_id
  ) pa ON pa.invoice_id = i.id
  LEFT JOIN (
    SELECT invoice_id, SUM(amount) AS credited
    FROM credit_allocation
    WHERE allocated_date < ?
    GROUP BY invoice_id
  ) ca ON ca.invoice_id = i.id
  LEFT JOIN (
    SELECT invoice_id, SUM(amount) AS adjusted
    FROM debtor_adjustment
    WHERE adjustment_date < ?
    GROUP BY invoice_id
  ) da ON da.invoice_id = i.id
  WHERE i.accounting_state != 'draft'
    AND COALESCE(i.issued_date, i.created_date) < ?
    AND (IFNULL(i.paid, 0) = 0 OR i.paid_date IS NULL OR i.paid_date >= ?)
    AND (IFNULL(i.external_sync_status, 0) NOT IN (?, ?) OR i.voided_date >= ?)
)
SELECT *
FROM invoice_balances
WHERE balance > 0
ORDER BY due_date ASC, invoice_id ASC
''',
      [
        cutoff,
        cutoff,
        cutoff,
        cutoff,
        cutoff,
        cutoff,
        InvoiceExternalSyncStatus.deleted.ordinal,
        InvoiceExternalSyncStatus.voided.ordinal,
        cutoff,
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
    final externalEnabled =
        externalAccountingEnabled ?? await ExternalAccounting().isEnabled();
    var openingBalance = MoneyEx.zero;
    final entries = <DebtorStatementEntry>[];

    for (final statementInvoice in invoices) {
      final invoice = statementInvoice.invoice;
      if (invoice.isExternallyDeletedOrVoided &&
          statementInvoice.voidedDate == null) {
        continue;
      }
      final invoiceNumber = invoice.displayNumber(
        externalAccountingEnabled: externalEnabled,
      );
      final customerName = statementInvoice.customerName;

      final issuedDate = statementInvoice.issuedDate;
      if (issuedDate.isBefore(startInclusive)) {
        openingBalance += invoice.totalAmount;
      } else if (issuedDate.isBefore(endExclusive)) {
        entries.add(
          DebtorStatementEntry(
            type: DebtorStatementEntryType.invoice,
            invoiceId: invoice.id,
            invoiceNumber: invoiceNumber,
            customerName: customerName,
            date: issuedDate,
            description: 'Invoice issued',
            amount: invoice.totalAmount,
          ),
        );
      }

      final voidedDate = statementInvoice.voidedDate;
      if (voidedDate != null) {
        if (voidedDate.isBefore(startInclusive)) {
          openingBalance -= invoice.totalAmount;
        } else if (voidedDate.isBefore(endExclusive)) {
          entries.add(
            DebtorStatementEntry(
              type: DebtorStatementEntryType.adjustment,
              invoiceId: invoice.id,
              invoiceNumber: invoiceNumber,
              customerName: customerName,
              date: voidedDate,
              description: 'Invoice voided',
              amount: -invoice.totalAmount,
            ),
          );
        }
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
        if (jobId == null &&
            history.type == InvoiceLedgerHistoryEntryType.payment) {
          continue;
        }
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

    // Customer statements follow the receipt, including any amount that has
    // not been allocated to an invoice. Job statements still use allocations
    // because a receipt can be split between jobs.
    if (jobId == null) {
      for (final payment in await _statementPayments(customerId)) {
        final amount = -payment.amount;
        if (payment.paymentDate.isBefore(startInclusive)) {
          openingBalance += amount;
        } else if (payment.paymentDate.isBefore(endExclusive)) {
          entries.add(
            DebtorStatementEntry(
              type: DebtorStatementEntryType.payment,
              invoiceId: 0,
              invoiceNumber: '',
              customerName: payment.customerName,
              date: payment.paymentDate,
              description: 'Payment received',
              amount: amount,
            ),
          );
        }
      }
      final creditRows = await _db.rawQuery(
        '''
SELECT c.customer_id, c.credit_date AS event_date, -c.amount AS amount,
 'Xero overpayment received' AS description, customer.name AS customer_name
FROM xero_customer_credit c JOIN customer ON customer.id = c.customer_id
WHERE (? IS NULL OR c.customer_id = ?)
UNION ALL
SELECT c.customer_id, e.event_date, e.amount,
 CASE WHEN e.kind = 'refund' THEN 'Xero overpayment refunded'
 ELSE 'Xero credit applied to an invoice outside this statement' END,
 customer.name
FROM xero_customer_credit_event e
JOIN xero_customer_credit c
 ON c.tenant_id = e.tenant_id AND c.external_id = e.credit_id
JOIN customer ON customer.id = c.customer_id
WHERE (? IS NULL OR c.customer_id = ?) AND (e.kind = 'refund' OR NOT EXISTS (
 SELECT 1 FROM invoice i JOIN job j ON j.id = i.job_id
 WHERE i.external_invoice_id = e.invoice_external_id
 AND COALESCE(i.billing_customer_id,j.bill_to_customer_id,j.customer_id) = c.customer_id
 AND i.accounting_state != 'draft'
))
''',
        [customerId, customerId, customerId, customerId],
      );
      for (final row in creditRows) {
        final date = DateTime.parse(row['event_date']! as String);
        final amount = MoneyEx.fromInt(row['amount']! as int);
        if (date.isBefore(startInclusive)) {
          openingBalance += amount;
        } else if (date.isBefore(endExclusive)) {
          entries.add(
            DebtorStatementEntry(
              type: amount.isNegative
                  ? DebtorStatementEntryType.payment
                  : DebtorStatementEntryType.adjustment,
              invoiceId: 0,
              invoiceNumber: '',
              customerName: row['customer_name']! as String,
              date: date,
              description: row['description']! as String,
              amount: amount,
            ),
          );
        }
      }
    }

    entries.sort((lhs, rhs) {
      final date = lhs.date.compareTo(rhs.date);
      if (date != 0) {
        return date;
      }
      final type = _statementEntrySortOrder(
        lhs.type,
      ).compareTo(_statementEntrySortOrder(rhs.type));
      if (type != 0) {
        return type;
      }
      final invoice = lhs.invoiceId.compareTo(rhs.invoiceId);
      if (invoice != 0) {
        return invoice;
      }
      return 0;
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
    final db = _db;
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
JOIN (
  SELECT payment_id, invoice_id, amount FROM debtor_payment_allocation
  UNION ALL
  SELECT p.id, NULL, p.amount - IFNULL(SUM(a.amount), 0)
  FROM debtor_payment p LEFT JOIN debtor_payment_allocation a ON a.payment_id = p.id
  GROUP BY p.id HAVING p.amount - IFNULL(SUM(a.amount), 0) != 0
) pa ON pa.payment_id = p.id
LEFT JOIN customer c ON c.id = p.customer_id
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
    final invoiceTax = await _invoiceTax(period: period);
    final creditTax = await _creditNoteTax(period: period);
    final unknown = await _db.rawQuery(
      '''
SELECT COUNT(*) AS count FROM (
  SELECT i.id FROM invoice i
  WHERE i.accounting_state != 'draft'
    AND (IFNULL(i.external_sync_status, 0) NOT IN (2, 3)
      OR i.voided_date IS NOT NULL)
    AND ((COALESCE(i.issued_date, i.created_date) >= ?
      AND COALESCE(i.issued_date, i.created_date) < ?)
      OR (i.voided_date >= ? AND i.voided_date < ?))
    AND (NOT EXISTS (SELECT 1 FROM invoice_line l WHERE l.invoice_id = i.id)
      OR EXISTS (SELECT 1 FROM invoice_line l WHERE l.invoice_id = i.id
        AND l.tax_code_id IS NULL AND NULLIF(l.tax_type, '') IS NULL
        AND IFNULL(l.tax_amount, 0) = 0 AND l.line_total != 0))
  UNION ALL
  SELECT c.id FROM credit_note c
  WHERE c.status IN (?, ?, ?) AND c.credit_date >= ? AND c.credit_date < ?
    AND (NOT EXISTS (SELECT 1 FROM credit_note_line l WHERE l.credit_note_id = c.id)
      OR EXISTS (SELECT 1 FROM credit_note_line l WHERE l.credit_note_id = c.id
        AND l.tax_code_id IS NULL AND NULLIF(l.tax_type, '') IS NULL
        AND IFNULL(l.tax_amount, 0) = 0 AND l.line_total != 0))
)
''',
      [
        ..._periodArgs(period),
        ..._periodArgs(period),
        CreditNoteStatus.approved.ordinal,
        CreditNoteStatus.partiallyAllocated.ordinal,
        CreditNoteStatus.allocated.ordinal,
        ..._periodArgs(period),
      ],
    );
    return TaxSummaryReport(
      period: period,
      taxLabel: taxLabel ?? await resolveTaxLabel(),
      taxCollected: invoiceTax,
      creditTax: creditTax,
      supplierTaxPaid: await _receiptTax(period: period),
      taxCollectedIsEstimated: false,
      unknownTaxDocuments: unknown.single['count']! as int,
    );
  }

  Future<SupplierSpendReport> supplierSpend(AccountingPeriod period) async {
    final db = _db;
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

  Future<UnlinkedCostReport> unlinkedCosts({AccountingPeriod? period}) async {
    final db = _db;
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
${_periodClause(period, 'r.receipt_date')}
ORDER BY r.receipt_date DESC, r.id DESC
''', _periodArgs(period));

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

  Future<MaterialBillingReport> materialsBilling({int? jobId}) async {
    final db = _db;
    final rows = await db.rawQuery(
      '''
SELECT
  ti.*,
  t.name AS report_task_name,
  j.id AS report_job_id,
  j.summary AS report_job_summary,
  IFNULL(c.name, 'Unknown customer') AS report_customer_name,
  COALESCE(t.billing_type, j.billing_type, 'timeAndMaterial')
    AS report_billing_type,
  IFNULL(j.hourly_rate, 0) AS report_hourly_rate,
  il.invoice_id AS report_invoice_id,
  i.invoice_num AS report_invoice_number
FROM task_item ti
JOIN task t ON t.id = ti.task_id
JOIN job j ON j.id = t.job_id
LEFT JOIN customer c ON c.id = j.customer_id
LEFT JOIN invoice_line il ON il.id = ti.invoice_line_id
LEFT JOIN invoice i ON i.id = il.invoice_id
WHERE ti.completed = 1
  AND (? IS NULL OR j.id = ?)
  AND ti.item_type_id != ${TaskItemType.labour.id}
  AND j.status_id NOT IN (
    '${JobStatus.onHold.id}',
    '${JobStatus.rejected.id}'
  )
  AND COALESCE(t.billing_type, j.billing_type, 'timeAndMaterial')
    != 'nonBillable'
ORDER BY
  CASE WHEN ti.actual_price_mode IS NULL THEN 0 ELSE 1 END,
  ti.billed,
  ti.modified_date DESC,
  ti.id DESC
''',
      [jobId, jobId],
    );

    final materialRows = <MaterialBillingRow>[];
    for (final row in rows) {
      final taskItem = _materialTaskItem(row);
      if (taskItem == null) {
        continue;
      }
      final billingType = _parseBillingType(row['report_billing_type']);
      final jobId = row['report_job_id'];
      if (jobId is! int) {
        continue;
      }

      materialRows.add(
        MaterialBillingRow(
          taskItem: taskItem,
          jobId: jobId,
          jobSummary: (row['report_job_summary'] as String?) ?? 'Unknown job',
          customerName:
              (row['report_customer_name'] as String?) ?? 'Unknown customer',
          taskName: (row['report_task_name'] as String?) ?? 'Unknown task',
          billingType: billingType,
          hourlyRate: MoneyEx.fromInt(row['report_hourly_rate'] as int?),
          invoiceId: row['report_invoice_id'] as int?,
          invoiceNumber: row['report_invoice_number'] as String?,
        ),
      );
    }

    return MaterialBillingReport(rows: materialRows);
  }

  BillingType _parseBillingType(Object? value) {
    if (value is! String) {
      return BillingType.timeAndMaterial;
    }
    for (final type in BillingType.values) {
      if (type.name == value) {
        return type;
      }
    }
    return BillingType.timeAndMaterial;
  }

  TaskItem? _materialTaskItem(Map<String, dynamic> row) {
    final itemTypeId = row['item_type_id'];
    if (itemTypeId is! int ||
        !TaskItemType.values.any((type) => type.id == itemTypeId)) {
      return null;
    }
    try {
      return TaskItem.fromMap(row);
    } catch (_) {
      return null;
    }
  }

  Future<Money> _invoiceIncome({AccountingPeriod? period, int? jobId}) =>
      _invoiceMovement(
        'i.total_amount - IFNULL((SELECT SUM(tax_amount) FROM invoice_line '
        'WHERE invoice_id = i.id), 0)',
        period: period,
        jobId: jobId,
      );

  Future<Money> _invoiceMovement(
    String amount, {
    AccountingPeriod? period,
    int? jobId,
  }) => _sum(
    '''
SELECT IFNULL(SUM(amount), 0) AS total FROM (
 SELECT $amount AS amount, COALESCE(i.issued_date, i.created_date) AS activity_date,
 i.job_id FROM invoice i WHERE i.accounting_state != 'draft'
 AND (IFNULL(i.external_sync_status, 0) NOT IN (2, 3) OR i.voided_date IS NOT NULL)
 UNION ALL
 SELECT -($amount), i.voided_date AS activity_date, i.job_id
 FROM invoice i WHERE i.accounting_state != 'draft' AND i.voided_date IS NOT NULL
) WHERE 1 = 1
${_periodClause(period, 'activity_date')}
${_jobClause(jobId, 'job_id')}
''',
    [..._periodArgs(period), ..._jobArgs(jobId)],
  );

  Future<List<_StatementInvoice>> _statementInvoicesForCustomer(
    int? customerId, {
    int? jobId,
  }) async {
    final where = <String>["i.accounting_state != 'draft'"];
    final args = <Object?>[];
    if (jobId != null) {
      where.add('i.job_id = ?');
      args.add(jobId);
    } else if (customerId != null) {
      where.add(
        'COALESCE(i.billing_customer_id, j.bill_to_customer_id, '
        'j.customer_id) = ?',
      );
      args.add(customerId);
    }
    final db = _db;
    final rows = await db.rawQuery('''
SELECT i.*, IFNULL(c.name, 'Unknown customer') AS statement_customer_name
FROM invoice i
LEFT JOIN job j ON j.id = i.job_id
LEFT JOIN customer c ON c.id = COALESCE(i.billing_customer_id, j.bill_to_customer_id, j.customer_id)
WHERE ${where.join(' AND ')}
ORDER BY i.created_date ASC, i.id ASC
''', args);

    return [
      for (final row in rows)
        _StatementInvoice(
          invoice: Invoice.fromMap(row),
          customerName: row['statement_customer_name']! as String,
          issuedDate: DateTime.parse(
            (row['issued_date'] ?? row['created_date'])! as String,
          ),
          voidedDate: DateTime.tryParse(row['voided_date'] as String? ?? ''),
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
    final db = _db;
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

    final overpaymentAllocations = await db.rawQuery('''
SELECT i.id AS invoice_id, e.event_date, e.amount
FROM xero_customer_credit_event e
JOIN invoice i ON i.external_invoice_id = e.invoice_external_id
WHERE e.kind = 'allocation' AND i.id IN ($placeholders)
''', invoiceIds);
    for (final row in overpaymentAllocations) {
      add(
        row['invoice_id']! as int,
        InvoiceLedgerHistoryEntry(
          type: InvoiceLedgerHistoryEntryType.payment,
          date: DateTime.parse(row['event_date']! as String),
          amount: MoneyEx.fromInt(row['amount']! as int),
          title: 'Xero overpayment allocated',
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

  Future<List<_StatementPayment>> _statementPayments(int? customerId) async {
    final rows = await _db.rawQuery(
      '''
SELECT p.payment_date, p.amount,
  IFNULL(c.name, 'Unknown customer') AS customer_name
FROM debtor_payment p
LEFT JOIN customer c ON c.id = p.customer_id
WHERE (? IS NULL OR p.customer_id = ?)
ORDER BY p.payment_date ASC, p.id ASC
''',
      [customerId, customerId],
    );
    return [
      for (final row in rows)
        _StatementPayment(
          paymentDate: DateTime.parse(row['payment_date']! as String),
          amount: MoneyEx.fromInt(row['amount']! as int),
          customerName: row['customer_name']! as String,
        ),
    ];
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

  int _statementEntrySortOrder(DebtorStatementEntryType type) => switch (type) {
    DebtorStatementEntryType.invoice => 0,
    DebtorStatementEntryType.payment => 1,
    DebtorStatementEntryType.credit => 2,
    DebtorStatementEntryType.adjustment => 3,
  };

  Future<Money> _creditNotes({AccountingPeriod? period, int? jobId}) => _sum(
    '''
SELECT IFNULL(SUM(total_amount - IFNULL((SELECT SUM(tax_amount)
  FROM credit_note_line WHERE credit_note_id = credit_note.id), 0)), 0) AS total
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

  Future<Money> _invoiceTax({AccountingPeriod? period}) => _invoiceMovement(
    'IFNULL((SELECT SUM(tax_amount) FROM invoice_line '
    'WHERE invoice_id = i.id), 0)',
    period: period,
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
    final db = _db;
    final rows = await db.rawQuery(sql, args);
    return MoneyEx.fromInt(rows.first['total'] as int? ?? 0);
  }

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
      rows.add([
        '',
        '',
        '',
        if (balance.isNegative) 'Closing credit balance' else 'Closing balance',
        '',
        balance,
      ]);
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
      rows.add([
        '',
        '',
        if (balance.isNegative) 'Closing credit balance' else 'Closing balance',
        '',
        balance,
      ]);
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

  String materialsBilling(MaterialBillingReport report) => _csv([
    [
      'Customer',
      'Job',
      'Task',
      'Item',
      'Type',
      'Actual cost',
      'Charge',
      'Billing status',
      'Invoice',
    ],
    for (final row in report.rows)
      [
        row.customerName,
        '#${row.jobId} ${row.jobSummary}',
        row.taskName,
        row.taskItem.description,
        row.taskItem.itemType.label,
        row.actualCost,
        row.charge,
        row.billingStatus,
        row.invoiceDisplay,
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

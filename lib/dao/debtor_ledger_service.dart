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
import 'package:strings/strings.dart';

import '../entity/entity.g.dart';
import '../util/dart/exceptions.dart';
import '../util/dart/money_ex.dart';
import 'dao_credit_allocation.dart';
import 'dao_credit_note.dart';
import 'dao_debtor_adjustment.dart';
import 'dao_debtor_payment.dart';
import 'dao_debtor_transaction.dart';
import 'dao_invoice.dart';
import 'dao_job.dart';
import 'dao_payment_allocation.dart';

enum DebtorInvoiceStatus {
  draft,
  sent,
  partPaid,
  paid,
  credited,
  overpaid,
  voided,
  writtenOff,
}

class InvoiceLedgerSummary {
  final Money total;
  final Money paid;
  final Money credited;
  final Money adjusted;
  final Money balance;
  final DebtorInvoiceStatus status;

  const InvoiceLedgerSummary({
    required this.total,
    required this.paid,
    required this.credited,
    required this.adjusted,
    required this.balance,
    required this.status,
  });

  bool get isClosed =>
      status == DebtorInvoiceStatus.paid ||
      status == DebtorInvoiceStatus.writtenOff ||
      status == DebtorInvoiceStatus.voided;

  bool get isOutstanding => balance.isPositive && !isClosed;
}

enum InvoiceLedgerHistoryEntryType { payment, credit, adjustment }

class InvoiceLedgerHistoryEntry {
  final InvoiceLedgerHistoryEntryType type;
  final DateTime date;
  final Money amount;
  final String title;
  final String? detail;

  const InvoiceLedgerHistoryEntry({
    required this.type,
    required this.date,
    required this.amount,
    required this.title,
    this.detail,
  });
}

class DebtorLedgerService {
  final DaoInvoice _daoInvoice;
  final DaoJob _daoJob;
  final DaoDebtorTransaction _daoTransaction;
  final DaoDebtorPayment _daoPayment;
  final DaoPaymentAllocation _daoPaymentAllocation;
  final DaoCreditNote _daoCreditNote;
  final DaoCreditAllocation _daoCreditAllocation;
  final DaoDebtorAdjustment _daoAdjustment;

  DebtorLedgerService({
    DaoInvoice? daoInvoice,
    DaoJob? daoJob,
    DaoDebtorTransaction? daoTransaction,
    DaoDebtorPayment? daoPayment,
    DaoPaymentAllocation? daoPaymentAllocation,
    DaoCreditNote? daoCreditNote,
    DaoCreditAllocation? daoCreditAllocation,
    DaoDebtorAdjustment? daoAdjustment,
  }) : _daoInvoice = daoInvoice ?? DaoInvoice(),
       _daoJob = daoJob ?? DaoJob(),
       _daoTransaction = daoTransaction ?? DaoDebtorTransaction(),
       _daoPayment = daoPayment ?? DaoDebtorPayment(),
       _daoPaymentAllocation = daoPaymentAllocation ?? DaoPaymentAllocation(),
       _daoCreditNote = daoCreditNote ?? DaoCreditNote(),
       _daoCreditAllocation = daoCreditAllocation ?? DaoCreditAllocation(),
       _daoAdjustment = daoAdjustment ?? DaoDebtorAdjustment();

  Future<DebtorTransaction> recordInvoice(Invoice invoice) async {
    final existing = await _daoTransaction.getBySource(
      type: DebtorTransactionType.invoice,
      sourceTable: 'invoice',
      sourceId: invoice.id,
    );
    if (existing != null) {
      return existing;
    }

    final job = await _daoJob.getById(invoice.jobId);
    final transaction = DebtorTransaction.forInsert(
      debtorCustomerId: job?.customerId,
      debtorContactId: invoice.billingContactId,
      jobId: invoice.jobId,
      transactionType: DebtorTransactionType.invoice,
      sourceTable: 'invoice',
      sourceId: invoice.id,
      transactionDate: invoice.createdDate,
      amount: invoice.totalAmount,
      taxAmount: MoneyEx.zero,
      description: 'Invoice #${invoice.bestNumber}',
    );
    await _daoTransaction.insert(transaction);
    return transaction;
  }

  Future<DebtorPayment> recordPayment({
    required int invoiceId,
    required Money amount,
    DateTime? paymentDate,
    String? paymentMethod,
    String? reference,
    String? notes,
  }) async {
    _requirePositive(amount, 'Payment amount');
    final invoice = await _requireInvoice(invoiceId);
    final job = await _daoJob.getById(invoice.jobId);
    final payment = DebtorPayment.forInsert(
      customerId: job?.customerId,
      contactId: invoice.billingContactId,
      paymentDate: paymentDate ?? DateTime.now(),
      amount: amount,
      paymentMethod: paymentMethod,
      reference: reference,
      notes: notes,
    );
    await _daoPayment.insert(payment);
    await allocatePayment(
      paymentId: payment.id,
      invoiceId: invoice.id,
      amount: amount,
      allocatedDate: payment.paymentDate,
    );
    await recordInvoice(invoice);
    return payment;
  }

  Future<PaymentAllocation> allocatePayment({
    required int paymentId,
    required int invoiceId,
    required Money amount,
    DateTime? allocatedDate,
  }) async {
    _requirePositive(amount, 'Payment allocation amount');
    final payment = await _daoPayment.getById(paymentId);
    if (payment == null) {
      throw HMBException('Payment $paymentId does not exist.');
    }
    await _requireInvoice(invoiceId);
    final allocated = await _daoPaymentAllocation.totalForPayment(paymentId);
    if (allocated + amount > payment.amount) {
      throw HMBException('Payment allocations exceed the payment amount.');
    }
    final allocation = PaymentAllocation.forInsert(
      paymentId: paymentId,
      invoiceId: invoiceId,
      amount: amount,
      allocatedDate: allocatedDate ?? DateTime.now(),
    );
    await _daoPaymentAllocation.insert(allocation);
    return allocation;
  }

  Future<CreditNote> createCreditNote({
    required int invoiceId,
    required Money amount,
    required String reason,
    DateTime? creditDate,
  }) async {
    _requirePositive(amount, 'Credit amount');
    if (Strings.isBlank(reason)) {
      throw HMBException('A credit reason is required.');
    }
    final invoice = await _requireInvoice(invoiceId);
    final job = await _daoJob.getById(invoice.jobId);
    final creditNote = CreditNote.forInsert(
      customerId: job?.customerId,
      contactId: invoice.billingContactId,
      jobId: invoice.jobId,
      relatedInvoiceId: invoice.id,
      creditDate: creditDate ?? DateTime.now(),
      totalAmount: amount,
      status: CreditNoteStatus.approved,
      reason: reason.trim(),
    );
    await _daoCreditNote.insert(creditNote);
    await allocateCredit(
      creditNoteId: creditNote.id,
      invoiceId: invoice.id,
      amount: amount,
      allocatedDate: creditNote.creditDate,
    );
    await recordInvoice(invoice);
    return creditNote;
  }

  Future<CreditAllocation> allocateCredit({
    required int creditNoteId,
    required int invoiceId,
    required Money amount,
    DateTime? allocatedDate,
  }) async {
    _requirePositive(amount, 'Credit allocation amount');
    final creditNote = await _daoCreditNote.getById(creditNoteId);
    if (creditNote == null) {
      throw HMBException('Credit note $creditNoteId does not exist.');
    }
    await _requireInvoice(invoiceId);
    final allocated = await _daoCreditAllocation.totalForCreditNote(
      creditNoteId,
    );
    if (allocated + amount > creditNote.totalAmount) {
      throw HMBException('Credit allocations exceed the credit note amount.');
    }
    final allocation = CreditAllocation.forInsert(
      creditNoteId: creditNoteId,
      invoiceId: invoiceId,
      amount: amount,
      allocatedDate: allocatedDate ?? DateTime.now(),
    );
    await _daoCreditAllocation.insert(allocation);

    final totalAllocated = allocated + amount;
    final nextStatus = totalAllocated == creditNote.totalAmount
        ? CreditNoteStatus.allocated
        : CreditNoteStatus.partiallyAllocated;
    await _daoCreditNote.update(creditNote.copyWith(status: nextStatus));
    return allocation;
  }

  Future<DebtorAdjustment> writeOffInvoiceBalance({
    required int invoiceId,
    required String reason,
    DateTime? adjustmentDate,
  }) async {
    final balance = await invoiceBalance(invoiceId);
    if (!balance.isPositive) {
      throw HMBException('Only a positive invoice balance can be written off.');
    }
    return addAdjustment(
      invoiceId: invoiceId,
      amount: balance,
      reason: reason,
      adjustmentType: DebtorAdjustmentType.writeOff,
      adjustmentDate: adjustmentDate,
    );
  }

  Future<DebtorAdjustment> writeOffSmallBalance({
    required int invoiceId,
    required String reason,
    Money? maxWriteOff,
    DateTime? adjustmentDate,
  }) async {
    final balance = await invoiceBalance(invoiceId);
    if (!balance.isPositive) {
      throw HMBException('Only a positive invoice balance can be written off.');
    }
    final limit = maxWriteOff ?? MoneyEx.fromInt(100);
    if (balance > limit) {
      throw HMBException(
        'The invoice balance is too large for a small balance write-off.',
      );
    }
    return addAdjustment(
      invoiceId: invoiceId,
      amount: balance,
      reason: reason,
      adjustmentType: DebtorAdjustmentType.writeOff,
      adjustmentDate: adjustmentDate,
    );
  }

  Future<DebtorAdjustment> addJournalAdjustment({
    required int invoiceId,
    required Money amount,
    required String reason,
    DebtorAdjustmentType adjustmentType = DebtorAdjustmentType.correction,
    DateTime? adjustmentDate,
    String? notes,
  }) => addAdjustment(
    invoiceId: invoiceId,
    amount: amount,
    reason: reason,
    adjustmentType: adjustmentType,
    adjustmentDate: adjustmentDate,
    notes: notes,
  );

  Future<DebtorAdjustment> addAdjustment({
    required int invoiceId,
    required Money amount,
    required String reason,
    DebtorAdjustmentType adjustmentType = DebtorAdjustmentType.correction,
    DateTime? adjustmentDate,
    String? notes,
  }) async {
    if (amount.isZero) {
      throw HMBException('Adjustment amount cannot be zero.');
    }
    if (Strings.isBlank(reason)) {
      throw HMBException('An adjustment reason is required.');
    }
    final invoice = await _requireInvoice(invoiceId);
    final job = await _daoJob.getById(invoice.jobId);
    final adjustment = DebtorAdjustment.forInsert(
      customerId: job?.customerId,
      contactId: invoice.billingContactId,
      jobId: invoice.jobId,
      invoiceId: invoice.id,
      adjustmentType: adjustmentType,
      adjustmentDate: adjustmentDate ?? DateTime.now(),
      amount: amount,
      reason: reason.trim(),
      notes: notes,
    );
    await _daoAdjustment.insert(adjustment);
    await recordInvoice(invoice);
    return adjustment;
  }

  Future<Money> invoicePaidAmount(int invoiceId) =>
      _daoPaymentAllocation.totalForInvoice(invoiceId);

  Future<Money> invoiceCreditedAmount(int invoiceId) =>
      _daoCreditAllocation.totalForInvoice(invoiceId);

  Future<Money> invoiceAdjustedAmount(int invoiceId) =>
      _daoAdjustment.totalForInvoice(invoiceId);

  Future<List<InvoiceLedgerHistoryEntry>> invoiceHistory(int invoiceId) async {
    await _requireInvoice(invoiceId);
    final entries = <InvoiceLedgerHistoryEntry>[];

    final paymentAllocations = await _daoPaymentAllocation.getByInvoiceId(
      invoiceId,
    );
    for (final allocation in paymentAllocations) {
      final payment = await _daoPayment.getById(allocation.paymentId);
      entries.add(
        InvoiceLedgerHistoryEntry(
          type: InvoiceLedgerHistoryEntryType.payment,
          date: allocation.allocatedDate,
          amount: allocation.amount,
          title: 'Payment received',
          detail: _paymentDetail(payment),
        ),
      );
    }

    final creditAllocations = await _daoCreditAllocation.getByInvoiceId(
      invoiceId,
    );
    for (final allocation in creditAllocations) {
      final creditNote = await _daoCreditNote.getById(allocation.creditNoteId);
      entries.add(
        InvoiceLedgerHistoryEntry(
          type: InvoiceLedgerHistoryEntryType.credit,
          date: allocation.allocatedDate,
          amount: allocation.amount,
          title: 'Credit applied',
          detail: creditNote?.reason,
        ),
      );
    }

    final adjustments = await _daoAdjustment.getByInvoiceId(invoiceId);
    for (final adjustment in adjustments) {
      entries.add(
        InvoiceLedgerHistoryEntry(
          type: InvoiceLedgerHistoryEntryType.adjustment,
          date: adjustment.adjustmentDate,
          amount: adjustment.amount,
          title: _adjustmentTitle(adjustment.adjustmentType),
          detail: adjustment.reason,
        ),
      );
    }

    entries.sort((lhs, rhs) => rhs.date.compareTo(lhs.date));
    return entries;
  }

  Future<InvoiceLedgerSummary> invoiceSummary(int invoiceId) async {
    final invoice = await _requireInvoice(invoiceId);
    final paid = await invoicePaidAmount(invoiceId);
    final credited = await invoiceCreditedAmount(invoiceId);
    final adjusted = await invoiceAdjustedAmount(invoiceId);
    final allocated = paid + credited + adjusted;

    if (allocated.isZero && invoice.paid) {
      return InvoiceLedgerSummary(
        total: invoice.totalAmount,
        paid: invoice.totalAmount,
        credited: MoneyEx.zero,
        adjusted: MoneyEx.zero,
        balance: MoneyEx.zero,
        status: invoice.isExternallyDeletedOrVoided
            ? DebtorInvoiceStatus.voided
            : DebtorInvoiceStatus.paid,
      );
    }

    final status = await _invoiceStatus(
      invoice: invoice,
      paid: paid,
      credited: credited,
      adjusted: adjusted,
    );
    return InvoiceLedgerSummary(
      total: invoice.totalAmount,
      paid: paid,
      credited: credited,
      adjusted: adjusted,
      balance: invoice.totalAmount - allocated,
      status: status,
    );
  }

  Future<Money> invoiceBalance(int invoiceId) async =>
      (await invoiceSummary(invoiceId)).balance;

  Future<DebtorInvoiceStatus> invoiceStatus(int invoiceId) async =>
      (await invoiceSummary(invoiceId)).status;

  Future<DebtorInvoiceStatus> _invoiceStatus({
    required Invoice invoice,
    required Money paid,
    required Money credited,
    required Money adjusted,
  }) async {
    if (invoice.isExternallyDeletedOrVoided) {
      return DebtorInvoiceStatus.voided;
    }

    final writtenOff = await _daoAdjustment.writeOffTotalForInvoice(invoice.id);
    final allocated = paid + credited + adjusted;
    final balance = invoice.totalAmount - allocated;

    if (balance.isNegative) {
      return DebtorInvoiceStatus.overpaid;
    }
    if (balance.isZero) {
      if (writtenOff.isNonZero) {
        return DebtorInvoiceStatus.writtenOff;
      }
      return DebtorInvoiceStatus.paid;
    }
    if (credited.isNonZero && paid.isZero && adjusted.isZero) {
      return DebtorInvoiceStatus.credited;
    }
    if (allocated.isNonZero) {
      return DebtorInvoiceStatus.partPaid;
    }
    return invoice.sent ? DebtorInvoiceStatus.sent : DebtorInvoiceStatus.draft;
  }

  Future<Invoice> _requireInvoice(int invoiceId) async {
    final invoice = await _daoInvoice.getById(invoiceId);
    if (invoice == null) {
      throw HMBException('Invoice $invoiceId does not exist.');
    }
    return invoice;
  }

  void _requirePositive(Money amount, String label) {
    if (!amount.isPositive) {
      throw HMBException('$label must be greater than zero.');
    }
  }

  String? _paymentDetail(DebtorPayment? payment) {
    if (payment == null) {
      return null;
    }
    final parts = [
      payment.paymentMethod,
      payment.reference,
      payment.notes,
    ].nonNulls.where(Strings.isNotBlank).map((part) => part.trim());
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
}

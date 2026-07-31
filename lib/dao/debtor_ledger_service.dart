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
import 'package:strings/strings.dart';

import '../entity/entity.g.dart';
import '../util/dart/exceptions.dart';
import '../util/dart/format.dart';
import '../util/dart/money_ex.dart';
import 'dao_accounting_sync_event.dart';
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
  static const externalProvider = 'xero';
  static const paymentEntity = 'payment';
  static const paymentAllocationEntity = 'payment_allocation';

  Future<DebtorTransaction> recordInvoice(Invoice invoice) async {
    final existing = await DaoDebtorTransaction().getBySource(
      type: DebtorTransactionType.invoice,
      sourceTable: 'invoice',
      sourceId: invoice.id,
    );
    if (existing != null) {
      return existing;
    }

    final job = await DaoJob().getById(invoice.jobId);
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
    await DaoDebtorTransaction().insert(transaction);
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
    final job = await DaoJob().getById(invoice.jobId);
    final payment = DebtorPayment.forInsert(
      customerId: job?.customerId,
      contactId: invoice.billingContactId,
      paymentDate: paymentDate ?? DateTime.now(),
      amount: amount,
      paymentMethod: paymentMethod,
      reference: reference,
      notes: notes,
    );
    await DaoDebtorPayment().insert(payment);
    await _queueCreate(paymentEntity, payment.id);
    await allocatePayment(
      paymentId: payment.id,
      invoiceId: invoice.id,
      amount: amount,
      allocatedDate: payment.paymentDate,
    );
    await recordInvoice(invoice);
    return payment;
  }

  Future<DebtorPayment> recordUnallocatedPayment({
    required int customerId,
    required Money amount,
    int? contactId,
    DateTime? paymentDate,
    String? paymentMethod,
    String? reference,
    String? notes,
  }) async {
    _requirePositive(amount, 'Payment amount');
    final payment = DebtorPayment.forInsert(
      customerId: customerId,
      contactId: contactId,
      paymentDate: paymentDate ?? DateTime.now(),
      amount: amount,
      paymentMethod: paymentMethod,
      reference: reference,
      notes: notes,
    );
    await DaoDebtorPayment().insert(payment);
    await _queueCreate(paymentEntity, payment.id);
    return payment;
  }

  Future<List<DebtorPayment>> unallocatedPaymentsForCustomer(int customerId) =>
      DaoDebtorPayment().getUnallocatedForCustomer(customerId);

  Future<Money> paymentAllocatedAmount(int paymentId) =>
      DaoDebtorPayment().allocatedAmount(paymentId);

  Future<Money> paymentUnallocatedAmount(DebtorPayment payment) =>
      DaoDebtorPayment().unallocatedAmount(payment);

  Future<PaymentAllocation> applyPaymentToInvoice({
    required int paymentId,
    required int invoiceId,
    required Money amount,
    DateTime? allocatedDate,
  }) async {
    final allocation = await allocatePayment(
      paymentId: paymentId,
      invoiceId: invoiceId,
      amount: amount,
      allocatedDate: allocatedDate,
    );
    await recordInvoice(await _requireInvoice(invoiceId));
    return allocation;
  }

  Future<PaymentAllocation> allocatePayment({
    required int paymentId,
    required int invoiceId,
    required Money amount,
    DateTime? allocatedDate,
  }) async {
    _requirePositive(amount, 'Payment allocation amount');
    final payment = await DaoDebtorPayment().getById(paymentId);
    if (payment == null) {
      throw HMBException('Payment $paymentId does not exist.');
    }
    final invoice = await _requireInvoice(invoiceId);
    await _requirePaymentForInvoiceCustomer(payment: payment, invoice: invoice);
    final allocated = await DaoPaymentAllocation().totalForPayment(paymentId);
    if (allocated + amount > payment.amount) {
      throw HMBException('Payment allocations exceed the payment amount.');
    }
    final allocation = PaymentAllocation.forInsert(
      paymentId: paymentId,
      invoiceId: invoiceId,
      amount: amount,
      allocatedDate: allocatedDate ?? DateTime.now(),
    );
    await DaoPaymentAllocation().insert(allocation);
    await _queueCreate(paymentAllocationEntity, allocation.id);
    return allocation;
  }

  Future<void> deletePayment(int paymentId) async {
    final payment = await DaoDebtorPayment().getById(paymentId);
    if (payment == null) {
      return;
    }
    await DaoDebtorPayment().withTransaction((transaction) async {
      final allocations = await DaoPaymentAllocation().getByPaymentId(
        paymentId,
        transaction,
      );
      for (final allocation in allocations) {
        await _queueDeleteOrSupersedeAllocation(
          allocation,
          transaction: transaction,
        );
        await DaoPaymentAllocation().delete(allocation.id, transaction);
      }
      await _queueDeleteOrSupersedePayment(payment, transaction: transaction);
      await DaoDebtorPayment().delete(payment.id, transaction);
    });
  }

  Future<void> deletePaymentAllocation(int allocationId) async {
    final allocation = await DaoPaymentAllocation().getById(allocationId);
    if (allocation == null) {
      return;
    }
    await DaoPaymentAllocation().withTransaction((transaction) async {
      await _queueDeleteOrSupersedeAllocation(
        allocation,
        transaction: transaction,
      );
      await DaoPaymentAllocation().delete(allocation.id, transaction);
    });
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
    final job = await DaoJob().getById(invoice.jobId);
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
    await DaoCreditNote().insert(creditNote);
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
    final creditNote = await DaoCreditNote().getById(creditNoteId);
    if (creditNote == null) {
      throw HMBException('Credit note $creditNoteId does not exist.');
    }
    await _requireInvoice(invoiceId);
    final allocated = await DaoCreditAllocation().totalForCreditNote(
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
    await DaoCreditAllocation().insert(allocation);

    final totalAllocated = allocated + amount;
    final nextStatus = totalAllocated == creditNote.totalAmount
        ? CreditNoteStatus.allocated
        : CreditNoteStatus.partiallyAllocated;
    await DaoCreditNote().update(creditNote.copyWith(status: nextStatus));
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
    final job = await DaoJob().getById(invoice.jobId);
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
    await DaoDebtorAdjustment().insert(adjustment);
    await recordInvoice(invoice);
    return adjustment;
  }

  Future<Money> invoicePaidAmount(int invoiceId) =>
      DaoPaymentAllocation().totalForInvoice(invoiceId);

  Future<Money> invoiceCreditedAmount(int invoiceId) =>
      DaoCreditAllocation().totalForInvoice(invoiceId);

  Future<Money> invoiceAdjustedAmount(int invoiceId) =>
      DaoDebtorAdjustment().totalForInvoice(invoiceId);

  Future<List<InvoiceLedgerHistoryEntry>> invoiceHistory(int invoiceId) async {
    await _requireInvoice(invoiceId);
    final entries = <InvoiceLedgerHistoryEntry>[];

    final paymentAllocations = await DaoPaymentAllocation().getByInvoiceId(
      invoiceId,
    );
    for (final allocation in paymentAllocations) {
      final payment = await DaoDebtorPayment().getById(allocation.paymentId);
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

    final creditAllocations = await DaoCreditAllocation().getByInvoiceId(
      invoiceId,
    );
    for (final allocation in creditAllocations) {
      final creditNote = await DaoCreditNote().getById(allocation.creditNoteId);
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

    final adjustments = await DaoDebtorAdjustment().getByInvoiceId(invoiceId);
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
    var paid = await invoicePaidAmount(invoiceId);
    final credited = await invoiceCreditedAmount(invoiceId);
    final adjusted = await invoiceAdjustedAmount(invoiceId);
    final allocated = paid + credited + adjusted;
    var balance = invoice.totalAmount - allocated;

    if (invoice.paid && balance.isPositive) {
      paid += balance;
      balance = MoneyEx.zero;
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
      balance: balance,
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

    final writtenOff = await DaoDebtorAdjustment().writeOffTotalForInvoice(
      invoice.id,
    );
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
    final invoice = await DaoInvoice().getById(invoiceId);
    if (invoice == null) {
      throw HMBException('Invoice $invoiceId does not exist.');
    }
    return invoice;
  }

  Future<void> _requirePaymentForInvoiceCustomer({
    required DebtorPayment payment,
    required Invoice invoice,
  }) async {
    if (payment.customerId == null) {
      return;
    }
    final job = await DaoJob().getById(invoice.jobId);
    if (job?.customerId != payment.customerId) {
      throw HMBException(
        'Payment ${payment.id} does not belong to the invoice customer.',
      );
    }
  }

  void _requirePositive(Money amount, String label) {
    if (!amount.isPositive) {
      throw HMBException('$label must be greater than zero.');
    }
  }

  Future<void> _queueCreate(String entityType, int localId) =>
      DaoAccountingSyncEvent().enqueue(
        provider: externalProvider,
        entityType: entityType,
        localId: localId,
        operation: AccountingSyncOperation.create,
      );

  Future<void> _queueDeleteOrSupersedePayment(
    DebtorPayment payment, {
    required Transaction transaction,
  }) async {
    final syncEvents = DaoAccountingSyncEvent();
    await syncEvents.supersedePendingCreates(
      provider: externalProvider,
      entityType: paymentEntity,
      localId: payment.id,
      transaction: transaction,
    );
    final externalId = payment.externalPaymentId;
    if (Strings.isNotBlank(externalId)) {
      await syncEvents.enqueue(
        provider: externalProvider,
        entityType: paymentEntity,
        localId: payment.id,
        externalId: externalId,
        operation: AccountingSyncOperation.delete,
        transaction: transaction,
      );
    }
  }

  Future<void> _queueDeleteOrSupersedeAllocation(
    PaymentAllocation allocation, {
    required Transaction transaction,
  }) async {
    final syncEvents = DaoAccountingSyncEvent();
    await syncEvents.supersedePendingCreates(
      provider: externalProvider,
      entityType: paymentAllocationEntity,
      localId: allocation.id,
      transaction: transaction,
    );
    final externalId = allocation.externalAllocationId;
    if (Strings.isNotBlank(externalId)) {
      await syncEvents.enqueue(
        provider: externalProvider,
        entityType: paymentAllocationEntity,
        localId: allocation.id,
        externalId: externalId,
        operation: AccountingSyncOperation.delete,
        transaction: transaction,
      );
    }
  }

  String? _paymentDetail(DebtorPayment? payment) {
    if (payment == null) {
      return null;
    }
    final parts = [
      'Payment date: ${formatDate(payment.paymentDate, format: 'j M Y')}',
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

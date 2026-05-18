import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/exceptions.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('recordInvoice creates an idempotent debtor transaction', () async {
    final invoice = await _insertInvoice(total: MoneyEx.dollars(100));
    final service = DebtorLedgerService();

    final first = await service.recordInvoice(invoice);
    final second = await service.recordInvoice(invoice);
    final transactions = await DaoDebtorTransaction().getByInvoiceId(
      invoice.id,
    );

    expect(first.id, second.id);
    expect(transactions, hasLength(1));
    expect(transactions.single.amount, MoneyEx.dollars(100));
    expect(transactions.single.transactionType, DebtorTransactionType.invoice);
  });

  test(
    'partial payment leaves invoice part paid and current paid flag alone',
    () async {
      final invoice = await _insertInvoice(total: MoneyEx.dollars(100));
      final service = DebtorLedgerService();

      await service.recordPayment(
        invoiceId: invoice.id,
        amount: MoneyEx.dollars(40),
      );

      expect(await service.invoicePaidAmount(invoice.id), MoneyEx.dollars(40));
      expect(await service.invoiceBalance(invoice.id), MoneyEx.dollars(60));
      expect(
        await service.invoiceStatus(invoice.id),
        DebtorInvoiceStatus.partPaid,
      );

      final reloaded = await DaoInvoice().getById(invoice.id);
      expect(reloaded!.paid, isFalse);
    },
  );

  test('legacy paid invoice is closed when no allocations exist', () async {
    final invoice = await _insertInvoice(
      total: MoneyEx.dollars(100),
      paid: true,
    );
    final service = DebtorLedgerService();

    final summary = await service.invoiceSummary(invoice.id);

    expect(summary.paid, MoneyEx.dollars(100));
    expect(summary.balance, MoneyEx.zero);
    expect(summary.status, DebtorInvoiceStatus.paid);
    expect(summary.isOutstanding, isFalse);
  });

  test('one payment can be split across multiple invoices', () async {
    final first = await _insertInvoice(total: MoneyEx.dollars(100));
    final second = await _insertInvoiceForJob(
      jobId: first.jobId,
      billingContactId: first.billingContactId,
      total: MoneyEx.dollars(100),
    );
    final job = await DaoJob().getById(first.jobId);
    final payment = DebtorPayment.forInsert(
      customerId: job!.customerId,
      contactId: first.billingContactId,
      paymentDate: DateTime.now(),
      amount: MoneyEx.dollars(150),
    );
    await DaoDebtorPayment().insert(payment);
    final service = DebtorLedgerService();

    await service.allocatePayment(
      paymentId: payment.id,
      invoiceId: first.id,
      amount: MoneyEx.dollars(100),
    );
    await service.allocatePayment(
      paymentId: payment.id,
      invoiceId: second.id,
      amount: MoneyEx.dollars(50),
    );

    expect(await service.invoiceBalance(first.id), MoneyEx.zero);
    expect(await service.invoiceBalance(second.id), MoneyEx.dollars(50));
    expect(await service.invoiceStatus(first.id), DebtorInvoiceStatus.paid);
    expect(
      await service.invoiceStatus(second.id),
      DebtorInvoiceStatus.partPaid,
    );
  });

  test('payment allocation cannot exceed payment amount', () async {
    final invoice = await _insertInvoice(total: MoneyEx.dollars(100));
    final job = await DaoJob().getById(invoice.jobId);
    final payment = DebtorPayment.forInsert(
      customerId: job!.customerId,
      contactId: null,
      paymentDate: DateTime.now(),
      amount: MoneyEx.dollars(50),
    );
    await DaoDebtorPayment().insert(payment);
    final service = DebtorLedgerService();

    await service.allocatePayment(
      paymentId: payment.id,
      invoiceId: invoice.id,
      amount: MoneyEx.dollars(40),
    );

    expect(
      () => service.allocatePayment(
        paymentId: payment.id,
        invoiceId: invoice.id,
        amount: MoneyEx.dollars(11),
      ),
      throwsA(isA<HMBException>()),
    );
  });

  test('payment cannot be applied to a different customer invoice', () async {
    final invoice = await _insertInvoice(total: MoneyEx.dollars(100));
    final otherInvoice = await _insertInvoice(total: MoneyEx.dollars(100));
    final otherJob = await DaoJob().getById(otherInvoice.jobId);
    final service = DebtorLedgerService();

    final payment = await service.recordUnallocatedPayment(
      customerId: otherJob!.customerId!,
      contactId: otherInvoice.billingContactId,
      amount: MoneyEx.dollars(100),
    );

    expect(
      () => service.applyPaymentToInvoice(
        paymentId: payment.id,
        invoiceId: invoice.id,
        amount: MoneyEx.dollars(100),
      ),
      throwsA(isA<HMBException>()),
    );
    expect(await service.invoicePaidAmount(invoice.id), MoneyEx.zero);
    expect(
      await service.paymentUnallocatedAmount(payment),
      MoneyEx.dollars(100),
    );
  });

  test('unallocated payment can be stored and later applied', () async {
    final invoice = await _insertInvoice(total: MoneyEx.dollars(100));
    final job = await DaoJob().getById(invoice.jobId);
    final service = DebtorLedgerService();

    final payment = await service.recordUnallocatedPayment(
      customerId: job!.customerId!,
      contactId: invoice.billingContactId,
      amount: MoneyEx.dollars(120),
      paymentDate: DateTime(2026, 5),
      reference: 'Deposit',
    );

    expect(
      await service.paymentUnallocatedAmount(payment),
      MoneyEx.dollars(120),
    );
    expect(
      await service.unallocatedPaymentsForCustomer(job.customerId!),
      hasLength(1),
    );

    await service.applyPaymentToInvoice(
      paymentId: payment.id,
      invoiceId: invoice.id,
      amount: MoneyEx.dollars(100),
      allocatedDate: DateTime(2026, 5, 2),
    );

    expect(await service.invoicePaidAmount(invoice.id), MoneyEx.dollars(100));
    expect(await service.invoiceBalance(invoice.id), MoneyEx.zero);
    expect(
      await service.paymentUnallocatedAmount(payment),
      MoneyEx.dollars(20),
    );
  });

  test('credit note allocation reduces invoice balance', () async {
    final invoice = await _insertInvoice(total: MoneyEx.dollars(100));
    final service = DebtorLedgerService();

    final creditNote = await service.createCreditNote(
      invoiceId: invoice.id,
      amount: MoneyEx.dollars(25),
      reason: 'Discount remaining balance',
    );

    expect(creditNote.status, CreditNoteStatus.approved);
    expect(
      await service.invoiceCreditedAmount(invoice.id),
      MoneyEx.dollars(25),
    );
    expect(await service.invoiceBalance(invoice.id), MoneyEx.dollars(75));
    expect(
      await service.invoiceStatus(invoice.id),
      DebtorInvoiceStatus.credited,
    );

    final reloadedCredit = await DaoCreditNote().getById(creditNote.id);
    expect(reloadedCredit!.status, CreditNoteStatus.allocated);
  });

  test('journal adjustment applies to invoice balance', () async {
    final invoice = await _insertInvoice(total: MoneyEx.dollars(100));
    final service = DebtorLedgerService();

    final adjustment = await service.addJournalAdjustment(
      invoiceId: invoice.id,
      amount: MoneyEx.dollars(15),
      reason: 'Manual correction',
    );

    expect(adjustment.reason, 'Manual correction');
    expect(
      await service.invoiceAdjustedAmount(invoice.id),
      MoneyEx.dollars(15),
    );
    expect(await service.invoiceBalance(invoice.id), MoneyEx.dollars(85));
  });

  test('write off clears remaining invoice balance', () async {
    final invoice = await _insertInvoice(total: MoneyEx.dollars(100));
    final service = DebtorLedgerService();
    await service.recordPayment(
      invoiceId: invoice.id,
      amount: MoneyEx.dollars(60),
    );

    final adjustment = await service.writeOffInvoiceBalance(
      invoiceId: invoice.id,
      reason: 'Uneconomical to chase',
    );

    expect(adjustment.amount, MoneyEx.dollars(40));
    expect(await service.invoiceBalance(invoice.id), MoneyEx.zero);
    expect(
      await service.invoiceStatus(invoice.id),
      DebtorInvoiceStatus.writtenOff,
    );
  });

  test('small balance write-off clears 40c underpayment', () async {
    final invoice = await _insertInvoice(total: MoneyEx.dollars(100));
    final service = DebtorLedgerService();
    await service.recordPayment(
      invoiceId: invoice.id,
      amount: MoneyEx.fromInt(9960),
    );

    final adjustment = await service.writeOffSmallBalance(
      invoiceId: invoice.id,
      reason: 'Customer underpaid by 40c',
      maxWriteOff: MoneyEx.fromInt(100),
    );

    expect(adjustment.amount, MoneyEx.fromInt(40));
    expect(adjustment.adjustmentType, DebtorAdjustmentType.writeOff);
    expect(await service.invoiceBalance(invoice.id), MoneyEx.zero);
    expect(
      await service.invoiceStatus(invoice.id),
      DebtorInvoiceStatus.writtenOff,
    );
  });

  test('invoice history includes payments credits and write-offs', () async {
    final invoice = await _insertInvoice(total: MoneyEx.dollars(100));
    final service = DebtorLedgerService();

    await service.recordPayment(
      invoiceId: invoice.id,
      amount: MoneyEx.dollars(50),
      paymentMethod: 'Bank',
      reference: 'REF-1',
    );
    await service.createCreditNote(
      invoiceId: invoice.id,
      amount: MoneyEx.dollars(25),
      reason: 'Goodwill credit',
    );
    await service.writeOffInvoiceBalance(
      invoiceId: invoice.id,
      reason: 'Uneconomical to chase',
    );

    final history = await service.invoiceHistory(invoice.id);

    expect(history, hasLength(3));
    expect(
      history.map((entry) => entry.type),
      containsAll([
        InvoiceLedgerHistoryEntryType.payment,
        InvoiceLedgerHistoryEntryType.credit,
        InvoiceLedgerHistoryEntryType.adjustment,
      ]),
    );
    expect(
      history
          .where((entry) => entry.type == InvoiceLedgerHistoryEntryType.payment)
          .single
          .detail,
      'Bank - REF-1',
    );
  });
}

Future<Invoice> _insertInvoice({
  required Money total,
  bool paid = false,
}) async {
  final job = await createJobWithCustomer(
    billingType: BillingType.timeAndMaterial,
    hourlyRate: MoneyEx.zero,
    summary: 'Debtor ledger test job',
  );
  final invoice = Invoice.forInsert(
    jobId: job.id,
    dueDate: LocalDate.today(),
    totalAmount: total,
    billingContactId: job.billingContactId,
    sent: true,
    paid: paid,
    paidDate: paid ? DateTime.now() : null,
  );
  await DaoInvoice().insert(invoice);
  return invoice;
}

Future<Invoice> _insertInvoiceForJob({
  required int jobId,
  required int? billingContactId,
  required Money total,
  bool paid = false,
}) async {
  final invoice = Invoice.forInsert(
    jobId: jobId,
    dueDate: LocalDate.today(),
    totalAmount: total,
    billingContactId: billingContactId,
    sent: true,
    paid: paid,
    paidDate: paid ? DateTime.now() : null,
  );
  await DaoInvoice().insert(invoice);
  return invoice;
}

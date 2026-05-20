import 'dart:convert';

import 'package:hmb/api/xero/xero_invoice_payment_sync_service.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/log.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../../ui/ui_test_helpers.dart';

void main() {
  setUpAll(() {
    Log.configure('.');
  });

  setUp(() async {
    await setupTestDb();
    final system = await DaoSystem().get();
    await DaoSystem().update(
      system.copyWith(enableXeroIntegration: true, xeroClientId: 'client-id'),
    );
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('does not attempt Xero login when no invoices need syncing', () async {
    var loginAttempts = 0;
    final service = XeroInvoicePaymentSyncService(
      daoInvoice: _EmptyPendingInvoiceDao(),
      login: ({allowInteractive = true}) async {
        loginAttempts += 1;
        return true;
      },
    );

    final updated = await service.sync(force: true);

    expect(updated, 0);
    expect(loginAttempts, 0);
  });

  test('imports Xero payments and credit notes into debtor ledger', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Xero sync debtor ledger job',
    );
    final invoice = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: MoneyEx.dollars(100),
      billingContactId: job.billingContactId,
      sent: true,
      externalInvoiceId: 'xero-invoice-1',
      paymentSource: InvoicePaymentSource.xero,
    );
    await DaoInvoice().insert(invoice);
    final service = XeroInvoicePaymentSyncService(
      login: ({allowInteractive = true}) async => true,
      getInvoice: (_) async => http.Response(
        jsonEncode({
          'Invoices': [
            {
              'Status': 'AUTHORISED',
              'AmountDue': 25,
              'AmountPaid': 50,
              'Payments': [
                {
                  'PaymentID': 'payment-1',
                  'Amount': 50,
                  'Date': '2026-05-01',
                  'Reference': 'Bank transfer',
                },
              ],
              'CreditNotes': [
                {
                  'CreditNoteID': 'credit-1',
                  'Total': 25,
                  'Date': '2026-05-02',
                  'CreditNoteNumber': 'CN-1',
                },
              ],
            },
          ],
        }),
        200,
      ),
    );

    final updated = await service.sync(force: true);

    expect(updated, 2);
    expect(
      await DebtorLedgerService().invoicePaidAmount(invoice.id),
      MoneyEx.dollars(50),
    );
    expect(
      await DebtorLedgerService().invoiceCreditedAmount(invoice.id),
      MoneyEx.dollars(25),
    );
    expect(
      await DebtorLedgerService().invoiceBalance(invoice.id),
      MoneyEx.dollars(25),
    );
    expect(
      await DaoDebtorPayment().getByExternalPaymentId(
        provider: 'xero',
        externalPaymentId: 'payment-1',
      ),
      isNotNull,
    );
    expect(
      await DaoCreditNote().getByExternalCreditNoteId('credit-1'),
      isNotNull,
    );

    final secondRun = await service.sync(force: true);
    expect(secondRun, 0);
  });

  test('retries paid Xero invoices until payment rows are available', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Xero paid debtor ledger job',
    );
    final invoice = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: MoneyEx.dollars(100),
      billingContactId: job.billingContactId,
      sent: true,
      paid: true,
      paidDate: DateTime(2026, 5, 3),
      externalInvoiceId: 'xero-paid-without-payments',
      externalSyncStatus: InvoiceExternalSyncStatus.linked,
      paymentSource: InvoicePaymentSource.xero,
    );
    await DaoInvoice().insert(invoice);
    var calls = 0;
    final service = XeroInvoicePaymentSyncService(
      login: ({allowInteractive = true}) async => true,
      getInvoice: (_) async {
        calls += 1;
        return http.Response(
          jsonEncode({
            'Invoices': [
              {
                'Status': 'PAID',
                'AmountDue': 0,
                'AmountPaid': 100,
                'FullyPaidOnDate': '2026-05-03',
                'Payments': calls == 1
                    ? <Map<String, dynamic>>[]
                    : [
                        {
                          'PaymentID': 'xero-payment-late',
                          'Amount': 100,
                          'Date': '2026-05-03',
                        },
                      ],
                'CreditNotes': <Map<String, dynamic>>[],
              },
            ],
          }),
          200,
        );
      },
    );

    final firstRun = await service.sync(force: true);

    expect(firstRun, 0);
    expect(
      await DebtorLedgerService().invoicePaidAmount(invoice.id),
      MoneyEx.zero,
    );
    expect(await DaoInvoice().getUploadedUnpaid(), hasLength(1));

    final secondRun = await service.sync(force: true);
    expect(secondRun, 1);
    expect(
      await DebtorLedgerService().invoicePaidAmount(invoice.id),
      MoneyEx.dollars(100),
    );
    expect(
      await DebtorLedgerService().invoiceBalance(invoice.id),
      MoneyEx.zero,
    );
    expect(
      await DaoDebtorPayment().getByExternalPaymentId(
        provider: 'xero',
        externalPaymentId: 'xero-payment-late',
      ),
      isNotNull,
    );
  });

  test('pushes local payments to Xero and stores external ids', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Xero outbound payment sync job',
    );
    final invoice = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: MoneyEx.dollars(100),
      billingContactId: job.billingContactId,
      sent: true,
      externalInvoiceId: 'xero-invoice-out',
      paymentSource: InvoicePaymentSource.xero,
    );
    await DaoInvoice().insert(invoice);
    await DebtorLedgerService().recordPayment(
      invoiceId: invoice.id,
      amount: MoneyEx.dollars(25),
      paymentDate: DateTime(2026, 5, 3),
      paymentMethod: '090',
      reference: 'Local payment',
    );
    final payloads = <Map<String, dynamic>>[];
    final service = XeroInvoicePaymentSyncService(
      login: ({allowInteractive = true}) async => true,
      getInvoice: (_) async => http.Response(
        jsonEncode({
          'Invoices': [
            {
              'Status': 'AUTHORISED',
              'AmountDue': 75,
              'AmountPaid': 25,
              'Payments': <Map<String, dynamic>>[],
              'CreditNotes': <Map<String, dynamic>>[],
            },
          ],
        }),
        200,
      ),
      createPayment: (payload) async {
        payloads.add(payload);
        return http.Response(
          jsonEncode({
            'Payments': [
              {'PaymentID': 'xero-payment-out'},
            ],
          }),
          200,
        );
      },
    );

    final updated = await service.sync(force: true);

    expect(updated, 1);
    expect(payloads.single['Amount'], '25');
    expect(
      await DaoDebtorPayment().getByExternalPaymentId(
        provider: 'xero',
        externalPaymentId: 'xero-payment-out',
      ),
      isNotNull,
    );
  });
}

class _EmptyPendingInvoiceDao extends DaoInvoice {
  @override
  Future<List<Invoice>> getUploadedUnpaid() async => [];
}

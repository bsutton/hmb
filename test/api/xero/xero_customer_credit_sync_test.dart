import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/api/xero/xero_customer_credit_sync.dart';
import 'package:hmb/api/xero/xero_invoice_payment_client.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:http/http.dart' as http;

import '../../database/management/db_utility_test_helper.dart';
import '../../ui/ui_test_helpers.dart';

void main() {
  late Job job;
  late Invoice invoice;
  late Map<String, dynamic> credit;
  late XeroCustomerCreditSync sync;
  var fail = false;
  setUp(() async {
    await setupTestDb();
    job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.dollars(100),
    );
    invoice = Invoice.forInsert(
      jobId: job.id,
      totalAmount: MoneyEx.dollars(100),
      dueDate: LocalDate.fromDateTime(DateTime(2026, 1, 10)),
      billingContactId: job.billingContactId,
      billingCustomerId: job.customerId,
      paymentSource: InvoicePaymentSource.xero,
    );
    await DaoInvoice().insert(invoice);
    await testDb!.update(
      'invoice',
      {
        'external_invoice_id': 'invoice-1',
        'paid': 1,
        'paid_date': '2026-01-10T00:00:00.000',
        'accounting_state': 'issued',
        'issued_date': '2026-01-01T00:00:00.000',
      },
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
    credit = {
      'OverpaymentID': 'credit-1',
      'Type': 'RECEIVE-OVERPAYMENT',
      'Status': 'AUTHORISED',
      'Contact': {'ContactID': 'contact-1'},
      'CurrencyCode': 'AUD',
      'Date': '2026-01-11',
      'Total': 100,
      'RemainingCredit': 100,
      'Allocations': <Object>[],
      'Payments': <Object>[],
    };
    fail = false;
    final client = XeroInvoicePaymentClient(
      login: ({allowInteractive = true}) async => true,
      getInvoice: (_) async => throw UnimplementedError(),
      createPayment: (_) async => throw UnimplementedError(),
      deletePayment: (_) async => throw UnimplementedError(),
      createCreditNote: (_) async => throw UnimplementedError(),
      allocateCreditNote: (_, _) async => throw UnimplementedError(),
      getTenantId: () async => 'tenant-1',
      getInvoiceBatch: (_) async => http.Response(
        jsonEncode({
          'Invoices': [
            {
              'InvoiceID': 'invoice-1',
              'Contact': {'ContactID': 'contact-1'},
            },
          ],
        }),
        200,
      ),
      getOverpayments: (_) async => fail
          ? http.Response('', 503)
          : http.Response(
              jsonEncode({
                'Overpayments': [credit],
              }),
              200,
            ),
    );
    sync = XeroCustomerCreditSync(testDb!, client);
  });
  tearDown(tearDownTestDb);

  Future<DebtorStatementReport> statement({int? jobId, DateTime? start}) =>
      AccountingReportService(externalAccountingEnabled: true).debtorStatement(
        customerId: job.customerId,
        jobId: jobId,
        startInclusive: start ?? DateTime(2026),
        endExclusive: DateTime(2027),
      );

  test(
    'paid invoice plus separate overpayment gives negative customer balance',
    () async {
      await sync.sync();
      final report = await statement();
      expect(report.closingBalance, MoneyEx.dollars(-100));
      expect(
        report.entries.where(
          (e) => e.description == 'Xero overpayment received',
        ),
        hasLength(1),
      );
      expect((await statement(jobId: job.id)).closingBalance, MoneyEx.zero);
      await sync.sync();
      expect((await statement()).closingBalance, MoneyEx.dollars(-100));
    },
  );

  test('credit before period becomes opening credit', () async {
    await sync.sync();
    final report = await statement(start: DateTime(2026, 2));
    expect(report.openingBalance, MoneyEx.dollars(-100));
    expect(report.closingBalance, MoneyEx.dollars(-100));
  });

  test('refund reduces credit without inventing an invoice payment', () async {
    credit['Payments'] = [
      {
        'PaymentID': 'refund-1',
        'Date': '2026-02-01',
        'Amount': 40,
        'Status': 'AUTHORISED',
      },
    ];
    credit['RemainingCredit'] = 60;
    await sync.sync();
    expect((await statement()).closingBalance, MoneyEx.dollars(-60));
  });

  test(
    'allocation to local invoice is not counted as another receipt',
    () async {
      // This invoice is paid entirely from the earlier customer credit.
      credit['Allocations'] = [
        {
          'AllocationID': 'allocation-1',
          'Date': '2026-01-12',
          'Amount': 100,
          'Invoice': {'InvoiceID': 'invoice-1'},
        },
      ];
      credit['RemainingCredit'] = 0;
      await sync.sync();
      expect((await statement()).closingBalance, MoneyEx.zero);
      expect((await statement(jobId: job.id)).closingBalance, MoneyEx.zero);
    },
  );

  test(
    'allocation to an invoice outside HMB consumes statement credit',
    () async {
      credit['Allocations'] = [
        {
          'AllocationID': 'allocation-2',
          'Date': '2026-01-12',
          'Amount': 100,
          'Invoice': {'InvoiceID': 'outside-hmb'},
        },
      ];
      credit['RemainingCredit'] = 0;
      await sync.sync();
      expect((await statement()).closingBalance, MoneyEx.zero);
    },
  );

  test('failed or incomplete sync retains previous credit snapshot', () async {
    await sync.sync();
    fail = true;
    await expectLater(sync.sync(), throwsException);
    expect((await statement()).closingBalance, MoneyEx.dollars(-100));
    fail = false;
    credit['RemainingCredit'] = 50;
    await expectLater(sync.sync(), throwsException);
    expect((await statement()).closingBalance, MoneyEx.dollars(-100));
  });

  test('voided credit is removed on a complete refresh', () async {
    await sync.sync();
    credit['Status'] = 'VOIDED';
    await sync.sync();
    expect((await statement()).closingBalance, MoneyEx.zero);
  });
}

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
  var invoiceStatus = 200;
  final requestedBatches = <List<String>>[];
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
    invoiceStatus = 200;
    requestedBatches.clear();
    final client = XeroInvoicePaymentClient(
      login: ({allowInteractive = true}) async => true,
      getInvoice: (_) async => throw UnimplementedError(),
      createPayment: (_) async => throw UnimplementedError(),
      deletePayment: (_) async => throw UnimplementedError(),
      createCreditNote: (_) async => throw UnimplementedError(),
      allocateCreditNote: (_, _) async => throw UnimplementedError(),
      getTenantId: () async => 'tenant-1',
      getInvoiceBatch: (ids) async {
        requestedBatches.add(List.of(ids));
        // Model the gateway rejecting oversized invoice-ID URLs.
        if (ids.length > 20) {
          return http.Response('', 404);
        }
        return http.Response(
          jsonEncode({
            'Invoices': [
              for (final id in ids)
                {
                  'InvoiceID': id,
                  'Contact': {'ContactID': 'contact-1'},
                },
            ],
          }),
          invoiceStatus,
        );
      },
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

  test(
    'large invoice history uses bounded URLs and imports the credit',
    () async {
      for (var i = 2; i <= 45; i++) {
        final values = (await testDb!.query(
          'invoice',
          where: 'id = ?',
          whereArgs: [invoice.id],
        )).single;
        await testDb!.insert('invoice', {
          ...values,
          'id': invoice.id + i,
          'invoice_num': 'batch-$i',
          'external_invoice_id': 'invoice-$i',
        });
      }
      expect(await sync.sync(), 1);
      expect(requestedBatches.map((batch) => batch.length), [20, 20, 5]);
      expect(requestedBatches.expand((batch) => batch).toSet(), hasLength(45));
      expect(
        (await testDb!.query('xero_customer_credit')).single['amount'],
        10000,
      );
    },
  );

  test(
    'sync failure identifies the failing Xero resource and status',
    () async {
      invoiceStatus = 404;
      await expectLater(
        sync.sync(),
        throwsA(
          predicate(
            (error) => '$error'.contains('Invoices request failed (HTTP 404)'),
          ),
        ),
      );
      invoiceStatus = 200;
      fail = true;
      await expectLater(
        sync.sync(),
        throwsA(
          predicate(
            (error) =>
                '$error'.contains('Overpayments request failed (HTTP 503)'),
          ),
        ),
      );
    },
  );

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

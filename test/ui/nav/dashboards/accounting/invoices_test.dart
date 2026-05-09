@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/nav/dashboards/accounting/invoices.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

import '../../../../database/management/db_utility_test_helper.dart';
import '../../../ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('partial payment still counts invoice as outstanding', () async {
    final invoice = await _insertInvoice(
      total: MoneyEx.dollars(100),
      dueDate: LocalDate.today().subtractDays(8),
    );

    await DebtorLedgerService().recordPayment(
      invoiceId: invoice.id,
      amount: MoneyEx.dollars(40),
    );

    final summary = await loadInvoiceCountSummary();

    expect(summary.outstanding, 1);
    expect(summary.paid, 0);
    expect(summary.overdue, 1);
    expect(summary.overdueSevenDays, 1);
  });

  test('full debtor payment counts invoice as paid', () async {
    final invoice = await _insertInvoice(total: MoneyEx.dollars(100));

    await DebtorLedgerService().recordPayment(
      invoiceId: invoice.id,
      amount: MoneyEx.dollars(100),
    );

    final summary = await loadInvoiceCountSummary();

    expect(summary.outstanding, 0);
    expect(summary.paid, 1);
    expect(summary.overdue, 0);
    expect(summary.overdueSevenDays, 0);
  });

  test('small balance write-off closes invoice in dashboard counts', () async {
    final invoice = await _insertInvoice(total: MoneyEx.dollars(100));
    final service = DebtorLedgerService();

    await service.recordPayment(
      invoiceId: invoice.id,
      amount: MoneyEx.fromInt(9960),
    );
    await service.writeOffSmallBalance(
      invoiceId: invoice.id,
      reason: 'Customer underpaid by 40c',
    );

    final summary = await loadInvoiceCountSummary();

    expect(summary.outstanding, 0);
    expect(summary.paid, 1);
  });

  test('legacy paid invoice stays paid in dashboard counts', () async {
    await _insertInvoice(total: MoneyEx.dollars(100), paid: true);

    final summary = await loadInvoiceCountSummary();

    expect(summary.outstanding, 0);
    expect(summary.paid, 1);
  });

  testWidgets('invoice dashlet summary keeps the tile compact', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.square(
            dimension: 150,
            child: Builder(
              builder: (context) => buildInvoiceCountSummary(
                context,
                const InvoiceCountSummary(
                  outstanding: 12,
                  paid: 34,
                  overdue: 5,
                  overdueSevenDays: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text('5 overdue, 2 7+ days'), findsOneWidget);
    expect(find.textContaining('paid'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<Invoice> _insertInvoice({
  required Money total,
  LocalDate? dueDate,
  bool paid = false,
}) async {
  final job = await createJobWithCustomer(
    billingType: BillingType.timeAndMaterial,
    hourlyRate: MoneyEx.zero,
    summary: 'Invoice dashlet ledger test job',
  );
  final invoice = Invoice.forInsert(
    jobId: job.id,
    dueDate: dueDate ?? LocalDate.today(),
    totalAmount: total,
    billingContactId: job.billingContactId,
    sent: true,
    paid: paid,
    paidDate: paid ? DateTime.now() : null,
  );
  await DaoInvoice().insert(invoice);
  return invoice;
}

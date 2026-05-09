@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/debtor_ledger_service.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/invoicing/invoice_details.dart';
import 'package:hmb/ui/invoicing/list_invoice_card.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

void main() {
  testWidgets('sent invoice shows Sent as its primary status', (tester) async {
    await _pumpCard(
      tester,
      invoice: _invoice(sent: true),
      ledgerStatus: DebtorInvoiceStatus.sent,
    );

    expect(find.text('Sent'), findsOneWidget);
    expect(find.textContaining('Outstanding due'), findsNothing);
    expect(find.text('Managed locally'), findsNothing);
  });

  testWidgets('written off invoice status takes priority over sent', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      invoice: _invoice(sent: true),
      ledgerStatus: DebtorInvoiceStatus.writtenOff,
      adjusted: MoneyEx.dollars(100),
      balance: MoneyEx.zero,
    );

    expect(find.text('Written off'), findsOneWidget);
    expect(find.text('Sent'), findsNothing);
    expect(find.textContaining('Outstanding:'), findsNothing);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required Invoice invoice,
  required DebtorInvoiceStatus ledgerStatus,
  Money? adjusted,
  Money? balance,
}) async {
  final total = invoice.totalAmount;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListInvoiceCard(
          invoiceDetails: InvoiceDetails(
            invoice: invoice,
            job: Job.forInsert(
              customerId: 1,
              summary: 'Bathroom repair',
              description: '',
              siteId: null,
              contactId: null,
              status: JobStatus.prospecting,
              hourlyRate: MoneyEx.zero,
              bookingFee: MoneyEx.zero,
              billingContactId: null,
            ),
            customer: Customer.forInsert(
              name: 'Test Customer',
              description: null,
              disbarred: false,
              customerType: CustomerType.residential,
              hourlyRate: MoneyEx.zero,
              billingContactId: null,
            ),
            ledger: InvoiceLedgerSummary(
              total: total,
              paid: MoneyEx.zero,
              credited: MoneyEx.zero,
              adjusted: adjusted ?? MoneyEx.zero,
              balance: balance ?? total,
              status: ledgerStatus,
            ),
            ledgerHistory: const [],
            lineGroups: const [],
          ),
          showJobDetails: false,
        ),
      ),
    ),
  );
}

Invoice _invoice({required bool sent}) => Invoice.forInsert(
  jobId: 1,
  dueDate: LocalDate.today().addDays(7),
  totalAmount: MoneyEx.dollars(100),
  billingContactId: null,
  sent: sent,
);

@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/invoicing/record_invoice_payment_dialog.dart';
import 'package:hmb/util/dart/money_ex.dart';

void main() {
  testWidgets('record payment dialog returns payment details', (tester) async {
    InvoicePaymentRequest? request;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                request = await showRecordInvoicePaymentDialog(
                  context: context,
                  balance: MoneyEx.dollars(100),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '40.00');
    await tester.enterText(find.byType(TextFormField).at(1), 'Bank');
    await tester.enterText(find.byType(TextFormField).at(2), 'REF-1');
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();

    expect(request, isNotNull);
    expect(request!.amount, MoneyEx.dollars(40));
    expect(request!.paymentMethod, 'Bank');
    expect(request!.reference, 'REF-1');
  });

  testWidgets('record payment dialog prevents overpayment', (tester) async {
    InvoicePaymentRequest? request;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                request = await showRecordInvoicePaymentDialog(
                  context: context,
                  balance: MoneyEx.dollars(100),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '100.01');
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();

    expect(request, isNull);
    expect(
      find.textContaining('Payment cannot exceed the invoice balance'),
      findsOneWidget,
    );
  });
}

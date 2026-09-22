import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/api/accounting/quickbooks_invoice_client.dart';
import 'package:hmb/entity/invoice.dart';
import 'package:hmb/entity/invoice_line.dart';
import 'package:hmb/entity/quickbooks_settings.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:money2/money2.dart';

void main() {
  Money money(int cents) => Money.fromInt(cents, isoCode: 'AUD');
  Invoice invoice() => Invoice.forInsert(
    jobId: 1,
    dueDate: LocalDate(2026, 10, 3),
    totalAmount: money(11000),
    billingContactId: 1,
  );
  InvoiceLine line({String? taxType = 'OUTPUT', int tax = 1000}) =>
      InvoiceLine.forInsert(
        invoiceId: 1,
        description: 'Progress invoice',
        quantity: Fixed.one,
        unitPrice: money(11000),
        lineTotal: money(11000),
        invoiceLineGroupId: 1,
        taxAmount: money(tax),
        taxType: taxType,
      );
  const settings = QuickBooksSettings(
    itemId: '1',
    taxableCode: 'TAX',
    exemptCode: 'NON',
    usTaxModel: true,
    transactionTaxCode: '2',
  );

  test('US export preserves currency and splits inclusive tax', () {
    final payload = quickBooksInvoicePayload(
      invoice: invoice(),
      lines: [line()],
      customerId: '10',
      settings: settings,
    );
    expect(payload['CurrencyRef'], {'value': 'AUD'});
    expect(payload['DueDate'], '2026-10-03');
    final first = (payload['Line'] as List).single as Map;
    expect(first['Amount'], 100);
    expect((payload['TxnTaxDetail'] as Map)['TotalTax'], 10);
  });
  test('explicit zero tax uses configured zero code', () {
    final payload = quickBooksInvoicePayload(
      invoice: invoice(),
      lines: [line(taxType: 'EXEMPTOUTPUT', tax: 0)],
      customerId: '10',
      settings: settings,
    );
    final first = (payload['Line'] as List).single as Map;
    expect((first['SalesItemLineDetail'] as Map)['TaxCodeRef'], {
      'value': 'NON',
    });
  });
  test('missing tax and inconsistent totals are refused', () {
    expect(
      () => quickBooksInvoicePayload(
        invoice: invoice(),
        lines: [line(taxType: null)],
        customerId: '10',
        settings: settings,
      ),
      throwsFormatException,
    );
    expect(
      () => quickBooksInvoicePayload(
        invoice: invoice(),
        lines: [line(), line()],
        customerId: '10',
        settings: settings,
      ),
      throwsFormatException,
    );
  });
  test('production callback requires HTTPS without query', () {
    expect(
      () => const QuickBooksSettings(
        clientId: 'id',
        sandbox: false,
        redirectUri: 'http://localhost/callback',
      ).validateAuth(),
      throwsFormatException,
    );
    const QuickBooksSettings(
      clientId: 'id',
      redirectUri: 'http://localhost/callback',
    ).validateAuth();
  });
  test('request key and sandbox destination survive invoice retry', () async {
    final requests = <http.Request>[];
    final client = QuickBooksInvoiceClient(
      realmId: '42',
      sandbox: true,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'Invoice': {'Id': '99', 'TotalAmt': 110},
          }),
          200,
        );
      }),
    );
    await client.createInvoice('{}', 'stable-key');
    await client.createInvoice('{}', 'stable-key');
    expect(
      requests.map((r) => r.url.queryParameters['requestid']),
      everyElement('stable-key'),
    );
    expect(requests.first.url.host, 'sandbox-quickbooks.api.intuit.com');
  });
  test('upstream error bodies are not exposed', () async {
    final client = QuickBooksInvoiceClient(
      realmId: '42',
      sandbox: false,
      client: MockClient((_) async => http.Response('sensitive payload', 401)),
    );
    await expectLater(
      client.customer('1'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          isNot(contains('sensitive')),
        ),
      ),
    );
    await expectLater(client.customer('../other'), throwsFormatException);
  });
}

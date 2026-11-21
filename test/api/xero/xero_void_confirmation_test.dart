import 'dart:convert';

import 'package:hmb/api/xero/xero_api.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test('omitted totals need complete empty allocation lists', () {
    final invoice = <String, Object?>{
      'InvoiceID': 'fixture',
      'Status': 'VOIDED',
      'Payments': [],
      'CreditNotes': [],
      'Prepayments': [],
      'Overpayments': [],
    };
    String? problem() => XeroApi.voidConfirmationProblem(
      http.Response(
        jsonEncode({
          'Invoices': [invoice],
        }),
        200,
      ),
      'fixture',
    );
    expect(problem(), isNull);
    invoice.remove('Prepayments');
    expect(problem(), contains('AmountCredited'));
    invoice['Payments'] = ['payment'];
    expect(problem(), contains('Payments'));
    expect(
      XeroApi.voidConfirmationProblem(http.Response('', 404), 'fixture'),
      contains('organisation'),
    );
  });

  test('only the matching voided Xero invoice with no ledger is confirmed', () {
    const id = 'test-remote-invoice-id';
    bool confirm([Map<String, Object?> overrides = const {}, int code = 200]) =>
        XeroApi.isConfirmedUnpaidVoid(
          http.Response(
            jsonEncode({
              'Invoices': [
                {
                  'InvoiceID': id,
                  'Status': 'VOIDED',
                  'AmountPaid': 0,
                  'AmountCredited': 0,
                  'Payments': <Object>[],
                  'CreditNotes': <Object>[],
                  ...overrides,
                },
              ],
            }),
            code,
          ),
          id,
        );
    expect(confirm(), isTrue);
    expect(confirm({'AmountPaid': '0.00', 'AmountCredited': '0.00'}), isTrue);
    expect(confirm({'Payments': null, 'CreditNotes': null}), isTrue);
    expect(
      confirm({
        'Overpayments': ['payment'],
      }),
      isFalse,
    );
    expect(confirm({'InvoiceID': 'other'}), isFalse);
    expect(confirm({'Status': 'AUTHORISED'}), isFalse);
    expect(confirm({'HasErrors': true}), isFalse);
    expect(confirm({'AmountPaid': 1}), isFalse);
    expect(confirm({'AmountCredited': 1}), isFalse);
    expect(
      confirm({
        'CreditNotes': ['credit'],
      }),
      isFalse,
    );
    expect(
      confirm({
        'Payments': ['payment'],
      }),
      isFalse,
    );
    expect(confirm({'AmountPaid': null}), isFalse);
    expect(confirm({}, 403), isFalse);
    expect(
      XeroApi.isConfirmedUnpaidVoid(http.Response('non-JSON', 200), id),
      isFalse,
    );
  });
}

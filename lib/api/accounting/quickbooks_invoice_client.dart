import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:money2/money2.dart';

import '../../entity/invoice.dart';
import '../../entity/invoice_line.dart';
import '../../entity/quickbooks_settings.dart';

class QuickBooksInvoiceClient {
  final http.Client client;
  final String realmId;
  final bool sandbox;
  QuickBooksInvoiceClient({
    required this.client,
    required this.realmId,
    required this.sandbox,
  });

  Uri _uri(String path, [Map<String, String> query = const {}]) => Uri.https(
    sandbox ? 'sandbox-quickbooks.api.intuit.com' : 'quickbooks.api.intuit.com',
    '/v3/company/$realmId/$path',
    query,
  );

  Future<Map<String, dynamic>> customer(String id) async {
    if (!RegExp(r'^\d+$').hasMatch(id)) {
      throw const FormatException('Enter a numeric QuickBooks customer ID.');
    }
    final response = await client
        .get(_uri('customer/$id'), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 30));
    return _read(response, 'Customer');
  }

  Future<Map<String, dynamic>> createInvoice(
    String payload,
    String requestId,
  ) async {
    final response = await client
        .post(
          _uri('invoice', {'requestid': requestId}),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: payload,
        )
        .timeout(const Duration(seconds: 30));
    return _read(response, 'Invoice');
  }

  Map<String, dynamic> _read(http.Response response, String name) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(
        'QuickBooks request failed (${response.statusCode}). '
        'Check authorization, customer/item IDs, currency and tax setup.',
      );
    }
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('QuickBooks returned an invalid response.');
    }
    final entity = map[name];
    if (entity is! Map<String, dynamic> || entity['Id'] is! String) {
      throw const FormatException('QuickBooks returned an invalid response.');
    }
    return entity;
  }
}

/// HMB amounts are tax-inclusive. Do not relabel AUD amounts as USD or infer
/// missing US sales tax amounts. ItemRef determines QBO's revenue account.
Map<String, dynamic> quickBooksInvoicePayload({
  required Invoice invoice,
  required List<InvoiceLine> lines,
  required String customerId,
  required QuickBooksSettings settings,
}) {
  if (settings.itemId.isEmpty ||
      settings.taxableCode.isEmpty ||
      settings.exemptCode.isEmpty ||
      lines.isEmpty) {
    throw const FormatException(
      'Configure the QuickBooks item and tax codes first.',
    );
  }
  final total = lines.fold<Money>(
    Money.fromInt(0, isoCode: invoice.totalAmount.currency.isoCode),
    (sum, line) => sum + line.lineTotal,
  );
  if (total != invoice.totalAmount) {
    throw const FormatException(
      'Invoice lines do not match the invoice total.',
    );
  }
  num amount(Money money) => num.parse(money.format('0.00'));
  final tax = lines.fold<Money>(
    Money.fromInt(0, isoCode: invoice.totalAmount.currency.isoCode),
    (sum, line) => sum + line.taxAmount,
  );
  if (lines.any((line) => line.taxType == null && line.taxCodeId == null)) {
    throw const FormatException(
      'Export requires explicit tax metadata on every '
      'invoice line. Missing tax must be reviewed, not treated as zero.',
    );
  }
  if (settings.usTaxModel &&
      tax.isNonZero &&
      settings.transactionTaxCode.isEmpty) {
    throw const FormatException('Configure the US transaction tax code.');
  }
  // Older Xero lines can carry OUTPUT with a zero placeholder tax amount.
  // Never turn that missing calculation into an exempt QuickBooks sale.
  const zeroTaxTypes = {'EXEMPTOUTPUT', 'ZERORATEDOUTPUT', 'NONE'};
  if (lines.any(
    (line) =>
        line.lineTotal.isNonZero &&
        line.taxAmount.isZero &&
        !zeroTaxTypes.contains(line.taxType),
  )) {
    throw const FormatException(
      'A zero-tax line has no explicit supported '
      'exemption. Review its tax before exporting.',
    );
  }
  return {
    'CustomerRef': {'value': customerId},
    'CurrencyRef': {'value': invoice.totalAmount.currency.isoCode},
    if (invoice.invoiceNum != null) 'DocNumber': invoice.invoiceNum,
    'TxnDate': invoice.createdDate.toIso8601String().substring(0, 10),
    'DueDate': invoice.dueDate.date.toIso8601String().substring(0, 10),
    if (!settings.usTaxModel) 'GlobalTaxCalculation': 'TaxInclusive',
    if (settings.usTaxModel)
      'TxnTaxDetail': {
        'TotalTax': amount(tax),
        if (settings.transactionTaxCode.isNotEmpty)
          'TxnTaxCodeRef': {'value': settings.transactionTaxCode},
      },
    'Line': [
      for (final line in lines)
        {
          'Description': line.description,
          'Amount': amount(
            settings.usTaxModel
                ? line.lineTotal - line.taxAmount
                : line.lineTotal,
          ),
          'DetailType': 'SalesItemLineDetail',
          'SalesItemLineDetail': {
            'ItemRef': {'value': settings.itemId},
            // A single total preserves HMB discounts and rounding exactly.
            'Qty': 1,
            'UnitPrice': amount(
              settings.usTaxModel
                  ? line.lineTotal - line.taxAmount
                  : line.lineTotal,
            ),
            'TaxCodeRef': {
              'value': line.taxAmount.isZero
                  ? settings.exemptCode
                  : settings.taxableCode,
            },
          },
        },
    ],
    'PrivateNote':
        'Exported from HMB invoice ${invoice.id}. '
        'Payment and lifecycle changes are not synchronized by this export.',
  };
}

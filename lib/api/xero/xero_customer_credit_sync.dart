import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sqflite_common/sqlite_api.dart';

import '../../util/dart/exceptions.dart';
import 'xero_invoice_payment_client.dart';

/// Imports whole customer receipts, refunds and allocations independently of
/// invoice settlement. A failed page never replaces the previous snapshot.
class XeroCustomerCreditSync {
  XeroCustomerCreditSync(this.db, this.client);
  final Database db;
  final XeroInvoicePaymentClient client;

  Future<int> sync() async {
    final invoices = client.getInvoiceBatch;
    final overpayments = client.getOverpayments;
    final tenantProvider = client.getTenantId;
    if (invoices == null || overpayments == null || tenantProvider == null) {
      return 0;
    }
    final tenant = await tenantProvider();
    final local = await db.rawQuery('''
SELECT i.external_invoice_id,
 COALESCE(i.billing_customer_id, j.bill_to_customer_id, j.customer_id) AS customer_id
FROM invoice i JOIN job j ON j.id = i.job_id
WHERE i.external_invoice_id IS NOT NULL AND i.external_invoice_id != ''
''');
    final customersByInvoice = <String, int>{};
    for (final row in local) {
      if (row['customer_id'] case final int customerId) {
        customersByInvoice[row['external_invoice_id']! as String] = customerId;
      }
    }
    final mapping = <String, Set<int>>{};
    final ids = customersByInvoice.keys.toList();
    for (var offset = 0; offset < ids.length; offset += 100) {
      final batch = ids.skip(offset).take(100).toList();
      final found = <String>{};
      for (final invoice in _rows(await invoices(batch), 'Invoices')) {
        found.add(invoice['InvoiceID'] as String);
        final customer = customersByInvoice[invoice['InvoiceID']];
        final contact = invoice['Contact'] as Map<String, dynamic>?;
        final contactId = contact?['ContactID'] as String?;
        if (customer != null && contactId != null) {
          mapping.putIfAbsent(contactId, () => {}).add(customer);
        }
      }
      if (!batch.every(found.contains)) {
        throw InvoiceException(
          'Some linked Xero invoices could not be read. '
          'The previous customer credit data has been retained.',
        );
      }
    }
    final credits = <Map<String, Object?>>[];
    final events = <Map<String, Object?>>[];
    var complete = false;
    for (var page = 1; page <= 1000; page++) {
      final rows = _rows(await overpayments(page), 'Overpayments');
      for (final row in rows) {
        if (row['Type'] != 'RECEIVE-OVERPAYMENT' || row['Status'] == 'VOIDED') {
          continue;
        }
        final contact = row['Contact'] as Map<String, dynamic>?;
        final customers = mapping[contact?['ContactID']];
        if (customers == null || customers.isEmpty) {
          continue;
        }
        if (customers.length != 1) {
          throw InvoiceException(
            'A Xero credit contact is shared by multiple '
            'bill-to customers. Resolve the customer mapping before syncing.',
          );
        }
        if (row['CurrencyCode'] != 'AUD') {
          throw InvoiceException(
            'A customer credit uses a different currency. '
            'It cannot be included in an AUD statement.',
          );
        }
        final id = row['OverpaymentID'] as String;
        final total = _minor(row['Total']);
        final remaining = _minor(row['RemainingCredit']);
        var used = 0;
        for (final allocation in _children(row, 'Allocations')) {
          final amount = _minor(allocation['Amount']);
          used += amount;
          events.add({
            'tenant_id': tenant,
            'credit_id': id,
            'event_id': 'allocation:${allocation['AllocationID']}',
            'kind': 'allocation',
            'event_date': _date(allocation['Date']),
            'amount': amount,
            'invoice_external_id': (allocation['Invoice'] as Map)['InvoiceID'],
          });
        }
        for (final refund in _children(row, 'Payments')) {
          if (refund['Status'] == 'DELETED') {
            continue;
          }
          final amount = _minor(refund['Amount']);
          used += amount;
          events.add({
            'tenant_id': tenant,
            'credit_id': id,
            'event_id': 'refund:${refund['PaymentID']}',
            'kind': 'refund',
            'event_date': _date(refund['Date']),
            'amount': amount,
            'invoice_external_id': null,
          });
        }
        if (total - used != remaining) {
          throw InvoiceException(
            'Xero credit history is incomplete. '
            'The previous statement credit data has been retained.',
          );
        }
        credits.add({
          'tenant_id': tenant,
          'external_id': id,
          'customer_id': customers.single,
          'credit_date': _date(row['Date']),
          'amount': total,
          'remaining_credit': remaining,
          'reference': row['Reference'] as String?,
        });
      }
      if (rows.length < 100) {
        complete = true;
        break;
      }
    }
    if (!complete) {
      throw InvoiceException('Xero credit pagination is incomplete.');
    }
    await db.transaction((txn) async {
      await txn.delete('xero_customer_credit_event');
      await txn.delete('xero_customer_credit');
      for (final credit in credits) {
        await txn.insert('xero_customer_credit', credit);
      }
      for (final event in events) {
        await txn.insert('xero_customer_credit_event', event);
      }
    });
    return credits.length;
  }

  List<Map<String, dynamic>> _rows(http.Response response, String field) {
    if (response.statusCode != 200) {
      throw InvoiceException(
        'Xero customer credit sync failed '
        '(HTTP ${response.statusCode}).',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body[field] is! List) {
      throw InvoiceException('Invalid Xero credit response.');
    }
    return (body[field] as List).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> _children(Map<String, dynamic> row, String key) =>
      (row[key] as List? ?? []).cast<Map<String, dynamic>>();

  int _minor(Object? value) {
    final amount = num.tryParse('$value');
    if (amount == null || !amount.isFinite || amount < 0) {
      throw InvoiceException('Invalid Xero credit amount.');
    }
    return (amount * 100).round();
  }

  String _date(Object? value) {
    final raw = '$value';
    final match = RegExp(r'^/Date\((\d+)(?:[+-]\d+)?\)/$').firstMatch(raw);
    final date = match == null
        ? DateTime.tryParse(raw)
        : DateTime.fromMillisecondsSinceEpoch(
            int.parse(match[1]!),
            isUtc: true,
          );
    if (date == null) {
      throw InvoiceException('Invalid Xero credit date.');
    }
    return DateTime(date.year, date.month, date.day).toIso8601String();
  }
}

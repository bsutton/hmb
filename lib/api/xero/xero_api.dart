/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../entity/invoice.dart';
import '../../util/dart/exceptions.dart';
import '../external_accounting.dart';
import 'models/xero_invoice.dart';
import 'xero_auth.dart';

class XeroApi {
  static const _baseUrl = 'https://api.xero.com/api.xro/2.0/';
  static final _instance = XeroApi._internal();

  String? _tenantId;

  XeroAuth2 xeroAuth;
  factory XeroApi() => _instance;

  XeroApi._internal() : xeroAuth = XeroAuth2();

  Future<void> login() async {
    await xeroAuth.login();
    await getTenantId();
  }

  Future<http.Response> uploadInvoice(XeroInvoice xeroInvoice) async {
    await _checkIntegration();

    final tenantId = await getTenantId();
    final response = await http.post(
      Uri.parse('${_baseUrl}Invoices'),
      headers: {
        'Authorization': 'Bearer ${xeroAuth.accessToken}',
        'Content-Type': 'application/json',
        'Xero-tenant-id': tenantId,
      },
      body: jsonEncode({
        'Invoices': [xeroInvoice.toJson()],
      }),
    );
    return response;
  }

  Future<http.Response> deleteInvoice(Invoice invoice) async {
    await _checkIntegration();

    final tenantId = await getTenantId();
    final response = await http.post(
      Uri.parse('${_baseUrl}Invoices/${invoice.invoiceNum}'),
      headers: {
        'Authorization': 'Bearer ${xeroAuth.accessToken}',
        'Content-Type': 'application/json',
        'Xero-tenant-id': tenantId,
      },
      body:
          '''
{
    "InvoiceNumber": "${invoice.invoiceNum}",
    "Status": "DELETED"
}
''',
    );
    if (response.statusCode != 200) {
      throw Exception('Error deleting invoice: ${response.body}');
    }
    return response;
  }

  /// Invoices which have been authorised cannot be deleted and
  /// instead must be voided.
  Future<http.Response> voidInvoice(Invoice invoice) async {
    await _checkIntegration();

    final tenantId = await getTenantId();
    final response = await http.post(
      Uri.parse('${_baseUrl}Invoices/${invoice.invoiceNum}'),
      headers: {
        'Authorization': 'Bearer ${xeroAuth.accessToken}',
        'Content-Type': 'application/json',
        'Xero-tenant-id': tenantId,
      },
      body:
          '''
{
    "InvoiceNumber": "${invoice.invoiceNum}",
    "Status": "VOIDED"
}
''',
    );
    if (response.statusCode != 200) {
      throw Exception('Error deleting invoice: ${response.body}');
    }
    return response;
  }

  /// Instruct xero to send the invoice to the jobs primary contact.
  Future<http.Response> sendInvoice(Invoice invoice) async {
    await _checkIntegration();

    final tenantId = await getTenantId();

    await markApproved(invoice);
    final response = await http.post(
      Uri.parse('${_baseUrl}Invoices/${invoice.externalInvoiceId}/Email'),
      headers: {
        'Authorization': 'Bearer ${xeroAuth.accessToken}',
        'Content-Type': 'application/json',
        'Xero-tenant-id': tenantId,
      },
      body: '',
    );
    if (response.statusCode != 204) {
      throw Exception('Error sending invoice: ${response.body}');
    }

    await markAsSent(invoice);
    return response;
  }

  /// Instruct xero to send the invoice to the job's primary contact.
  Future<http.Response> markApproved(Invoice invoice) async {
    await _checkIntegration();
    final tenantId = await getTenantId();
    final response = await http.post(
      Uri.parse('${_baseUrl}Invoices/${invoice.externalInvoiceId}'),
      headers: {
        'Authorization': 'Bearer ${xeroAuth.accessToken}',
        'Content-Type': 'application/json',
        'Xero-tenant-id': tenantId,
      },
      body:
          '''
{
    "InvoiceID": "${invoice.externalInvoiceId}",
    "Status": "AUTHORISED"
}
''',
    );
    if (response.statusCode != 200) {
      throw Exception('Error marking invoice as authorised: ${response.body}');
    }
    return response;
  }

  /// Mark the invoice in xero as sent.
  Future<http.Response> markAsSent(Invoice invoice) async {
    await _checkIntegration();
    final tenantId = await getTenantId();
    final response = await http.post(
      Uri.parse('${_baseUrl}Invoices/${invoice.externalInvoiceId}'),
      headers: {
        'Authorization': 'Bearer ${xeroAuth.accessToken}',
        'Content-Type': 'application/json',
        'Xero-tenant-id': tenantId,
      },
      body:
          '''
{
    "InvoiceID": "${invoice.externalInvoiceId}",
    "SentToContact": "true"
}
''',
    );
    if (response.statusCode != 200) {
      throw Exception('Error marking invoice as sent: ${response.body}');
    }
    return response;
  }

  Future<http.Response> getContact(String contactName) async {
    await _checkIntegration();
    final tenantId = await getTenantId();
    final response = await http.get(
      Uri.parse('${_baseUrl}Contacts?where=Name=="$contactName"'),
      headers: {
        'Authorization': 'Bearer ${xeroAuth.accessToken}',
        'Content-Type': 'application/json',
        'Xero-tenant-id': tenantId,
      },
    );
    return response;
  }

  Future<http.Response> createContact(Map<String, dynamic> contact) async {
    await _checkIntegration();
    final tenantId = await getTenantId();
    final response = await http.post(
      Uri.parse('${_baseUrl}Contacts'),
      headers: {
        'Authorization': 'Bearer ${xeroAuth.accessToken}',
        'Content-Type': 'application/json',
        'Xero-tenant-id': tenantId,
      },
      body: jsonEncode({
        'Contacts': [contact],
      }),
    );
    return response;
  }

  Future<http.Response> getInvoice(String externalInvoiceId) async {
    await _checkIntegration();
    final tenantId = await getTenantId();
    return http.get(
      Uri.parse('${_baseUrl}Invoices/$externalInvoiceId'),
      headers: {
        'Authorization': 'Bearer ${xeroAuth.accessToken}',
        'Content-Type': 'application/json',
        'Xero-tenant-id': tenantId,
      },
    );
  }

  Future<String> getTenantId() async {
    await _checkIntegration();
    if (_tenantId != null) {
      return _tenantId!;
    }

    final response = await http.get(
      Uri.parse('https://api.xero.com/connections'),
      headers: {'Authorization': 'Bearer ${xeroAuth.accessToken}'},
    );

    if (response.statusCode == 200) {
      final connections = jsonDecode(response.body) as List<dynamic>;
      if (connections.isNotEmpty) {
        _tenantId =
            // ignore: avoid_dynamic_calls
            connections[0]['tenantId'] as String; // Get the first tenant ID
        return _tenantId!;
      } else {
        throw Exception('No tenant connections found.');
      }
    } else {
      throw Exception('Failed to get tenant ID: ${response.body}');
    }
  }

  Future<void> _checkIntegration() async {
    if (!(await ExternalAccounting().isEnabled())) {
      throw IntegrationDisabledExcpetion(
        'Xero integration is disabled. Check System | Integration',
      );
    }
  }
}

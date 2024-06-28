import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/models.dart';

class XeroApi {
  XeroApi(this._accessToken);
  final String _baseUrl = 'https://api.xero.com/api.xro/2.0/';
  final String _accessToken;

  Future<http.Response> createInvoice(Invoice invoice) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}Invoices'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(invoice.toJson()),
    );
    return response;
  }

  Future<http.Response> getAccounts() async {
    final response = await http.get(
      Uri.parse('${_baseUrl}Accounts'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );
    return response;
  }
}

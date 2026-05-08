import 'package:http/http.dart' as http;

import 'xero_invoice_payment_client_stub.dart'
    if (dart.library.ui) 'xero_invoice_payment_client_flutter.dart';

typedef XeroLogin = Future<bool> Function({bool allowInteractive});
typedef XeroGetInvoice = Future<http.Response> Function(String externalId);
typedef XeroCreatePayment =
    Future<http.Response> Function(Map<String, dynamic> payment);
typedef XeroCreateCreditNote =
    Future<http.Response> Function(Map<String, dynamic> creditNote);
typedef XeroAllocateCreditNote =
    Future<http.Response> Function(
      String creditNoteId,
      Map<String, dynamic> allocation,
    );

class XeroInvoicePaymentClient {
  final XeroLogin login;
  final XeroGetInvoice getInvoice;
  final XeroCreatePayment createPayment;
  final XeroCreateCreditNote createCreditNote;
  final XeroAllocateCreditNote allocateCreditNote;

  XeroInvoicePaymentClient({
    required this.login,
    required this.getInvoice,
    required this.createPayment,
    required this.createCreditNote,
    required this.allocateCreditNote,
  });
}

XeroInvoicePaymentClient createDefaultXeroInvoicePaymentClient() =>
    createXeroInvoicePaymentClient();

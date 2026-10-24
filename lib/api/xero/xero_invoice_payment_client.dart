import 'package:http/http.dart' as http;

import 'xero_invoice_payment_client_stub.dart'
    if (dart.library.ui) 'xero_invoice_payment_client_flutter.dart';

typedef XeroLogin = Future<bool> Function({bool allowInteractive});
typedef XeroGetInvoice = Future<http.Response> Function(String externalId);
typedef XeroCreatePayment =
    Future<http.Response> Function(Map<String, dynamic> payment);
typedef XeroDeletePayment = Future<http.Response> Function(String paymentId);
typedef XeroGetInvoiceBatch = Future<http.Response> Function(List<String> ids);
typedef XeroGetOverpayments = Future<http.Response> Function(int page);
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
  final XeroDeletePayment deletePayment;
  final XeroCreateCreditNote createCreditNote;
  final XeroAllocateCreditNote allocateCreditNote;
  final XeroGetInvoiceBatch? getInvoiceBatch;
  final XeroGetOverpayments? getOverpayments;
  final XeroGetOverpayments? getPrepayments;
  final XeroGetOverpayments? getCreditNotes;
  final Future<String> Function()? getTenantId;

  XeroInvoicePaymentClient({
    required this.login,
    required this.getInvoice,
    required this.createPayment,
    required this.deletePayment,
    required this.createCreditNote,
    required this.allocateCreditNote,
    this.getInvoiceBatch,
    this.getOverpayments,
    this.getPrepayments,
    this.getCreditNotes,
    this.getTenantId,
  });
}

XeroInvoicePaymentClient createDefaultXeroInvoicePaymentClient() =>
    createXeroInvoicePaymentClient();

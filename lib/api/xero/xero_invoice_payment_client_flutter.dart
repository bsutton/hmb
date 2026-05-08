import 'xero_api.dart';
import 'xero_invoice_payment_client.dart';

XeroInvoicePaymentClient createXeroInvoicePaymentClient() {
  final xeroApi = XeroApi();
  return XeroInvoicePaymentClient(
    login: xeroApi.login,
    getInvoice: xeroApi.getInvoice,
    createPayment: xeroApi.createPayment,
    createCreditNote: xeroApi.createCreditNote,
    allocateCreditNote: xeroApi.allocateCreditNote,
  );
}

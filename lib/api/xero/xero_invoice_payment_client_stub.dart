import 'xero_invoice_payment_client.dart';

XeroInvoicePaymentClient createXeroInvoicePaymentClient() =>
    XeroInvoicePaymentClient(
      login: ({allowInteractive = true}) async =>
          throw UnsupportedError('Xero login requires Flutter.'),
      getInvoice: (_) async =>
          throw UnsupportedError('Xero invoice access requires Flutter.'),
      createPayment: (_) async =>
          throw UnsupportedError('Xero payment access requires Flutter.'),
      createCreditNote: (_) async =>
          throw UnsupportedError('Xero credit note access requires Flutter.'),
      allocateCreditNote: (_, _) async => throw UnsupportedError(
        'Xero credit allocation access requires Flutter.',
      ),
    );

import '../../entity/invoice.dart';

/// Invoice export is separate from payment and lifecycle synchronization.
abstract interface class InvoiceExportProvider {
  String get displayName;
  Future<String> exportInvoice(Invoice invoice, {required String customerId});
}

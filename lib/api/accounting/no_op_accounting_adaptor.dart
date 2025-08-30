import '../../entity/invoice.dart';
import 'accounting_adaptor.dart';

class NoOpAccountingAdaptor extends AccountingAdaptor {
  @override
  Future<void> login() async {}
  @override
  Future<void> markSent(Invoice invoice) async {}
  @override
  Future<void> markApproved(Invoice invoice) async {}
  @override
  Future<void> uploadInvoice(Invoice invoice) async {}
}

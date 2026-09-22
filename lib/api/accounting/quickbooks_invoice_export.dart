import 'dart:convert';

import '../../dao/dao_invoice.dart';
import '../../dao/dao_invoice_line.dart';
import '../../dao/dao_quickbooks.dart';
import '../../entity/invoice.dart';
import 'invoice_export_provider.dart';
import 'quickbooks_auth.dart';
import 'quickbooks_invoice_client.dart';

class QuickBooksInvoiceExport implements InvoiceExportProvider {
  @override
  String get displayName => 'QuickBooks Online';

  Future<String> customerName(String id) async {
    final settings = await DaoQuickBooks().settings();
    return await QuickBooksAuth().withClient((client, realmId) async {
      final customer = await QuickBooksInvoiceClient(
        client: client,
        realmId: realmId,
        sandbox: settings.sandbox,
      ).customer(id);
      if (customer['Active'] == false) {
        throw const FormatException('QuickBooks customer is inactive.');
      }
      return customer['DisplayName'] as String? ?? id;
    });
  }

  @override
  Future<String> exportInvoice(
    Invoice invoice, {
    required String customerId,
  }) async {
    invoice =
        await DaoInvoice().getById(invoice.id) ??
        (throw const FormatException('Invoice no longer exists.'));
    if (invoice.isUploaded() || invoice.isExternallyDeletedOrVoided) {
      throw const FormatException(
        'This invoice is already externally managed or voided.',
      );
    }
    final dao = DaoQuickBooks();
    final settings = await dao.settings();
    final lines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
    final payload = jsonEncode(
      quickBooksInvoicePayload(
        invoice: invoice,
        lines: lines,
        customerId: customerId,
        settings: settings,
      ),
    );
    return await QuickBooksAuth().withClient((client, realmId) async {
      final prepared = await dao.prepareExport(
        invoiceId: invoice.id,
        realmId: realmId,
        sandbox: settings.sandbox,
        payload: payload,
      );
      if (prepared['external_id'] != null) {
        final actual = num.tryParse(prepared['remote_total'].toString());
        final expected = num.parse(invoice.totalAmount.format('0.00'));
        if (actual == null || (actual - expected).abs() > 0.005) {
          throw const FormatException(
            'An export already exists with an '
            'unverified total. Review it in QuickBooks.',
          );
        }
        return prepared['external_number'] as String? ??
            prepared['external_id']! as String;
      }
      final remote = await QuickBooksInvoiceClient(
        client: client,
        realmId: realmId,
        sandbox: settings.sandbox,
      ).createInvoice(payload, prepared['request_id']! as String);
      // Persist mismatched totals so a retry cannot duplicate the invoice.
      await dao.completeExport(invoice.id, remote);
      final remoteTotal = num.tryParse(remote['TotalAmt'].toString());
      final expected = num.parse(invoice.totalAmount.format('0.00'));
      if (remoteTotal == null || (remoteTotal - expected).abs() > 0.005) {
        throw const FormatException(
          'QuickBooks created the invoice but returned a '
          'different total. Review it in QuickBooks. '
          'Do not export another copy.',
        );
      }
      return remote['DocNumber'] as String? ?? remote['Id']! as String;
    });
  }
}

import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/accounting/quickbooks_invoice_export.dart';
import '../../dao/dao_quickbooks.dart';
import '../../entity/invoice.dart';
import '../widgets/fields/hmb_text_field.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/widgets.g.dart';

class QuickBooksExportScreen extends StatefulWidget {
  final Invoice invoice;
  const QuickBooksExportScreen({required this.invoice, super.key});
  @override
  State<QuickBooksExportScreen> createState() => _ExportState();
}

class _ExportState extends DeferredState<QuickBooksExportScreen> {
  final _customer = TextEditingController();
  String? _customerName;
  String? _verifiedId;
  Map<String, Object?>? _export;
  var _sandbox = true;
  Object? get _remoteNumber =>
      _export?['external_number'] ?? _export?['external_id'];

  @override
  Future<void> asyncInitState() async {
    _export = await DaoQuickBooks().exportFor(widget.invoice.id);
    _sandbox = (await DaoQuickBooks().settings()).sandbox;
  }

  @override
  void dispose() {
    _customer.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    await BlockingUI().runAndWait(() async {
      try {
        await action();
      } on FormatException catch (error) {
        HMBToast.error(error.message);
      } catch (_) {
        HMBToast.error(
          'QuickBooks action failed. Review the connection and export status.',
        );
      } finally {
        _export = await DaoQuickBooks().exportFor(widget.invoice.id);
      }
    });
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Export to QuickBooks',
    maxContentWidth: 800,
    child: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, _) => const Text('Could not load export settings.'),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Invoice #${widget.invoice.id}: ${widget.invoice.totalAmount}'),
          Text(
            _sandbox
                ? 'Destination: sandbox company'
                : 'Destination: LIVE company',
          ),
          const Text(
            'Preview integration — live tax and authorization testing '
            'is pending. This creates an invoice snapshot without requesting '
            'email delivery. Check your company automations separately. '
            'Later edits, voids and payments must be reconciled separately in '
            'both systems. Do not also upload this invoice to Xero.',
          ),
          if (_export != null)
            Text(
              _export!['external_id'] == null
                  ? 'An export was attempted. Retry only the same invoice '
                        'and customer; '
                        'check QuickBooks first if its outcome is uncertain.'
                  : 'QuickBooks invoice: '
                        '$_remoteNumber'
                        '. '
                        'Stored total: ${_export!['remote_total']}. '
                        'Review it in QuickBooks.',
            ),
          if (_export?['external_id'] == null) ...[
            HMBTextField(
              controller: _customer,
              labelText: 'QuickBooks customer ID',
              onChanged: (_) => setState(() {
                _customerName = null;
                _verifiedId = null;
              }),
            ),
            HMBButtonSecondary(
              label: 'Check customer',
              hint: 'Retrieve the customer name from QuickBooks',
              onPressed: () => _run(() async {
                final id = _customer.text.trim();
                _customerName = await QuickBooksInvoiceExport().customerName(
                  id,
                );
                _verifiedId = id;
              }),
            ),
            if (_customerName != null) ...[
              Text('Export to customer: $_customerName (ID $_verifiedId)'),
              const Text(
                'Confirm that the customer, currency and tax settings '
                'are correct before creating the invoice.',
              ),
              HMBButtonPrimary(
                label: 'Confirm and export',
                hint: 'Create this invoice in QuickBooks',
                onPressed: () => _run(() async {
                  if (_verifiedId != _customer.text.trim()) {
                    return;
                  }
                  final number = await QuickBooksInvoiceExport().exportInvoice(
                    widget.invoice,
                    customerId: _verifiedId!,
                  );
                  HMBToast.info(
                    'QuickBooks invoice $number created. '
                    'Review before sending.',
                  );
                }),
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

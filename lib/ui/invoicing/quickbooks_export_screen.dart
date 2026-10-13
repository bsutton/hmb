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
  final Future<Map<String, Object?>?> Function(int)? loadExport;
  final Future<bool> Function()? loadSandbox;
  const QuickBooksExportScreen({
    required this.invoice,
    this.loadExport,
    this.loadSandbox,
    super.key,
  });
  @override
  State<QuickBooksExportScreen> createState() => _ExportState();
}

class _ExportState extends DeferredState<QuickBooksExportScreen> {
  final _customer = TextEditingController();
  String? _customerName;
  String? _verifiedId;
  Map<String, Object?>? _export;
  var _sandbox = true;
  var _busy = false;
  var _loadFailed = false;
  Object? get _remoteNumber =>
      _export?['external_number'] ?? _export?['external_id'];

  @override
  Future<void> asyncInitState() async {
    await _load();
  }

  Future<void> _load() async {
    try {
      await BlockingUI().runAndWait(() async {
        _export = await (widget.loadExport ?? DaoQuickBooks().exportFor)(
          widget.invoice.id,
        );
        _sandbox =
            await (widget.loadSandbox ??
                () async => (await DaoQuickBooks().settings()).sandbox)();
      }, label: 'Opening accounting export');
      _loadFailed = false;
    } catch (_) {
      _loadFailed = true;
    }
  }

  @override
  void dispose() {
    _customer.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await BlockingUI().runAndWait(() async {
        try {
          await action();
        } finally {
          // Failed requests may already have a persisted attempt or remote ID.
          _export = await DaoQuickBooks().exportFor(widget.invoice.id);
        }
      }, label: 'Checking accounting export');
    } on FormatException catch (error) {
      HMBToast.error(error.message);
    } catch (_) {
      HMBToast.error(
        'Accounting action failed. Review the connection and export status.',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Send to accounting',
    maxContentWidth: 800,
    child: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, _) => const Text('Could not load export settings.'),
      builder: (_) => _loadFailed
          ? HMBFormList(
              children: [
                const Text('Could not load export settings.'),
                HMBButtonSecondary(
                  label: 'Retry',
                  hint: 'Reload accounting export settings',
                  onPressed: () async {
                    await _load();
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Invoice #${widget.invoice.id}: '
                  '${widget.invoice.totalAmount}',
                ),
                Text(
                  _sandbox
                      ? 'Destination: sandbox company'
                      : 'Destination: LIVE company',
                ),
                const Text(
                  'Payments and later changes must be reconciled separately '
                  'in both systems.',
                ),
                if (_export?['external_id'] == null)
                  const Text(
                    'Preview integration: live tax and authorization testing '
                    'is pending. Export creates a snapshot without requesting '
                    'email delivery. Check company automations before export. '
                    'Do not export this invoice to another '
                    'accounting provider.',
                  ),
                if (_export != null)
                  Text(
                    _export!['external_id'] == null
                        ? 'An export was attempted. Retry only the same '
                              'invoice '
                              'and customer; '
                              'check your accounting software first if its '
                              'outcome '
                              'is uncertain.'
                        : 'Accounting invoice: '
                              '$_remoteNumber'
                              '. '
                              'Stored total: ${_export!['remote_total']}. '
                              'Review it in your accounting software.',
                  ),
                if (_export?['external_id'] == null) ...[
                  HMBTextField(
                    controller: _customer,
                    enabled: !_busy,
                    labelText: 'Accounting customer ID',
                    onChanged: (_) => setState(() {
                      _customerName = null;
                      _verifiedId = null;
                    }),
                  ),
                  HMBButtonSecondary(
                    label: 'Check customer',
                    hint: 'Retrieve the customer name from accounting',
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final id = _customer.text.trim();
                            _customerName = await QuickBooksInvoiceExport()
                                .customerName(id);
                            _verifiedId = id;
                          }),
                  ),
                  if (_customerName != null) ...[
                    Text(
                      'Export to customer: $_customerName (ID $_verifiedId)',
                    ),
                    const Text(
                      'Confirm that the customer, currency and tax settings '
                      'are correct before creating the invoice.',
                    ),
                    HMBButtonPrimary(
                      label: 'Confirm and export',
                      enabled: !_busy,
                      hint: 'Create this invoice in accounting',
                      onPressed: () => _run(() async {
                        if (_verifiedId != _customer.text.trim()) {
                          return;
                        }
                        final number = await QuickBooksInvoiceExport()
                            .exportInvoice(
                              widget.invoice,
                              customerId: _verifiedId!,
                            );
                        HMBToast.info(
                          'Accounting invoice $number created. '
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

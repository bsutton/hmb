import 'dart:typed_data';

import 'package:deferred_state/deferred_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../dao/accounting_invoice_export.dart';
import '../../../../dao/accounting_report_service.dart';
import '../../../widgets/fields/hmb_text_field.dart';
import '../../../widgets/layout/layout.g.dart';
import '../../../widgets/select/hmb_droplist.dart';
import '../../../widgets/widgets.g.dart';

class AccountingImportScreen extends StatefulWidget {
  final AccountingPeriod period;
  const AccountingImportScreen({required this.period, super.key});
  @override
  State<AccountingImportScreen> createState() => _AccountingImportScreenState();
}

class _AccountingImportScreenState
    extends DeferredState<AccountingImportScreen> {
  final _service = AccountingInvoiceExport();
  late InvoiceExportData _data;
  AccountantImportTarget _target = AccountantImportTarget.xero;
  final _account = TextEditingController();
  final _imported = TextEditingController();
  final _customers = <int, TextEditingController>{};
  final _codes = <String, TextEditingController>{};
  final _rates = <String, TextEditingController>{};
  InvoiceImportFiles? _result;
  String? _error;

  @override
  Future<void> asyncInitState() async {
    _data = await BlockingUI().runAndWait(() => _service.load(widget.period));
    for (final customer in _data.customers.entries) {
      _customers[customer.key] = TextEditingController(text: customer.value);
    }
    for (final key in _data.taxKeys) {
      _codes[key] = TextEditingController();
      _rates[key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _account,
      _imported,
      ..._customers.values,
      ..._codes.values,
      ..._rates.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed(String? _) => setState(() => _result = null);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Accounting invoice export')),
    body: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, error) => Text('Unable to load invoices: $error'),
      builder: (_) => HMBFormList(
        children: [
          const Text(
            'Export sales invoices for Xero or QuickBooks Online. '
            'Use the accountant pack for payments, credits and expenses.',
          ),
          HMBDroplist<AccountantImportTarget>(
            title: 'Receiving system',
            items: (_) async => AccountantImportTarget.values,
            selectedItem: () async => _target,
            format: (target) => switch (target) {
              AccountantImportTarget.xero => 'Xero',
              AccountantImportTarget.quickBooksAustralia =>
                'QuickBooks Online Australia',
              AccountantImportTarget.quickBooksUS =>
                'QuickBooks Online US (no sales tax)',
            },
            onChanged: (target) => setState(() {
              if (target != null) {
                _target = target;
              }
              _result = null;
            }),
          ),
          if (_target == AccountantImportTarget.xero)
            HMBTextField(
              controller: _account,
              labelText: 'Xero revenue account code',
              onChanged: _changed,
            ),
          const Text('Customer names must match the receiving system exactly.'),
          HMBFormSection(
            children: [
              for (final customer in _customers.entries)
                HMBTextField(
                  controller: customer.value,
                  labelText:
                      'Customer #${customer.key}: '
                      '${_data.customers[customer.key]}',
                  onChanged: _changed,
                ),
            ],
          ),
          const Text(
            'Map each recorded tax code to the receiving system. '
            'Enter its percentage to check it reproduces the stored tax. '
            'Unknown historical tax is excluded.',
          ),
          for (final key in _data.taxKeys)
            if (key != 'unknown')
              HMBFormSection(
                children: [
                  Text('HMB tax code: $key'),
                  HMBTextField(
                    controller: _codes[key]!,
                    labelText: 'Target tax code/name',
                    onChanged: _changed,
                  ),
                  HMBTextField(
                    controller: _rates[key]!,
                    labelText: 'Tax rate (%)',
                    onChanged: _changed,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
          HMBTextField(
            controller: _imported,
            labelText: 'Previously imported HMB invoice IDs (comma separated)',
            onChanged: _changed,
          ),
          const Text(
            'Keep the export manifest after importing. For a retry, '
            'exclude invoices that succeeded. '
            'Files cannot check the target for duplicates.',
          ),
          HMBButton(
            label: 'Review export',
            hint: 'Validate mappings and invoice totals',
            onPressed: _review,
          ),
          if (_error != null) Text(_error!),
          if (_result != null) ...[
            Text(
              '${_result!.invoiceCount} invoices ready; '
              '${_result!.exclusions.length - 1} excluded.',
            ),
            for (final row in _result!.exclusions.skip(1))
              Text('Invoice #${row[0]}: ${row[1]}'),
            HMBButton(
              label: 'Save import files',
              hint: 'Save CSV batches, exclusions and import instructions',
              enabled: _result!.invoiceCount > 0,
              onPressed: _save,
            ),
          ],
        ],
      ),
    ),
  );

  void _review() {
    try {
      final imported = <int>{};
      for (final value in _imported.text.split(',')) {
        if (value.trim().isEmpty) {
          continue;
        }
        final id = int.tryParse(value.trim());
        if (id == null) {
          throw ArgumentError('Use comma-separated numeric HMB IDs.');
        }
        imported.add(id);
      }
      final result = _service.build(
        _data,
        target: _target,
        revenueAccount: _account.text,
        customers: {for (final c in _customers.entries) c.key: c.value.text},
        taxMappings: {
          for (final c in _codes.entries)
            c.key: ImportTaxMapping(
              c.value.text,
              double.tryParse(_rates[c.key]!.text) ?? double.nan,
            ),
        },
        alreadyImported: imported,
      );
      setState(() {
        _result = result;
        _error = null;
      });
    } catch (error) {
      setState(() {
        _result = null;
        _error = error.toString();
      });
    }
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null) {
      return;
    }
    await BlockingUI().runAndWait(() async {
      await FilePicker.saveFile(
        dialogTitle: 'Save accounting import files',
        fileName: 'hmb_${_target.name}_invoices.zip',
        bytes: Uint8List.fromList(result.zip()),
      );
    });
  }
}

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../dao/dao_invoice.dart';
import '../dao/dao_invoice_line.dart';
import '../dao/dao_invoice_line_group.dart';
import '../dao/dao_job.dart';
import '../entity/invoice.dart';
import '../entity/invoice_line.dart';
import '../entity/invoice_line_group.dart';
import '../entity/job.dart';
import '../util/format.dart';
import '../widgets/hmb_are_you_sure_dialog.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_one_of.dart';
import '../widgets/hmb_toast.dart';
import 'dialog_select_tasks.dart';
import 'edit_invoice_line_dialog.dart';
import 'xero/xero_api.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({
    required this.job,
    super.key,
  });
  final Job job;

  @override
  // ignore: library_private_types_in_public_api
  _InvoiceListScreenState createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  late Future<List<Invoice>> _invoices;
  late Future<bool> _hasUnbilledItems;
  late XeroApi _xeroApi;

  @override
  void initState() {
    super.initState();

    // ignore: discarded_futures
    _invoices = DaoInvoice().getByJobId(widget.job.id);
    // ignore: discarded_futures
    _hasUnbilledItems = DaoJob().hasBillableTasks(widget.job);
  }

  Future<void> _createInvoice() async {
    final selectedTasks = await DialogTaskSelection.show(context, widget.job);

    if (selectedTasks.isNotEmpty) {
      // Create invoice (and invoice lines)
      await DaoInvoice().create(widget.job, selectedTasks);

      // Refresh state
      await _refresh();
    }
  }

  Future<void> _uploadInvoiceToXero(Invoice invoice) async {
    try {
      _xeroApi = XeroApi();
      await _xeroApi.login();
      await DaoInvoice().uploadInvoiceToXero(invoice, _xeroApi);
      await _refresh();
      if (mounted) {
        HMBToast.info( 'Invoice uploaded to Xero successfully');
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      if (mounted) {
        HMBToast.error('Failed to upload invoice: $e',
            acknowledgmentRequired: true);
      }
    }
  }

  Future<void> _refresh() async {
    // Refresh state
    _invoices = DaoInvoice().getByJobId(widget.job.id);
    _hasUnbilledItems = DaoJob().hasBillableTasks(widget.job);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Invoices for Job: ${widget.job.summary}'),
        ),
        body: Column(
          children: [
            _buildCreateInvoiceButton(),
            _buildInvoiceList(),
          ],
        ),
      );

  /// Build the list of invoices.
  Widget _buildInvoiceList() => Expanded(
        child: FutureBuilderEx<List<Invoice>>(
          future: _invoices,
          builder: (context, invoices) {
            if (invoices!.isEmpty) {
              return const Center(child: Text('No invoices found.'));
            }

            return ListView.builder(
              itemCount: invoices.length,
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                return _buildInvoice(invoice);
              },
            );
          },
        ),
      );

  /// Build a single invoice.
  Widget _buildInvoice(Invoice invoice) => Container(
        color: Colors.grey[200],
        child: ExpansionTile(
          title: _buildInvoiceTitle(invoice),
          subtitle: Text('Total: ${invoice.totalAmount}'),
          children: [
            FutureBuilderEx<List<InvoiceLineGroup>>(
              // ignore: discarded_futures
              future: DaoInvoiceLineGroup().getByInvoiceId(invoice.id),
              builder: (context, invoiceLineGroups) {
                if (invoiceLineGroups!.isEmpty) {
                  return const ListTile(
                    title: Text('No invoice lines found.'),
                  );
                }

                return _buildInvoiceGroup(invoiceLineGroups);
              },
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton(
                  onPressed: () async => _uploadInvoiceToXero(invoice),
                  child: _buildXeroButton(invoice)),
            )
          ],
        ),
      );

  Widget _buildXeroButton(Invoice invoice) {
    if (invoice.invoiceNum == null) {
      return const Text('Upload to Xero');
    } else {
      return const Text('Send from Xero');
    }
  }

  Padding _buildInvoiceGroup(List<InvoiceLineGroup> invoiceLineGroups) =>
      Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Column(
          children: invoiceLineGroups
              .map((group) => ExpansionTile(
                    title: Text(group.name),
                    children: [
                      FutureBuilderEx<List<InvoiceLine>>(
                        future:
                            // ignore: discarded_futures
                            DaoInvoiceLine().getByInvoiceLineGroupId(group.id),
                        builder: (context, invoiceLines) {
                          if (invoiceLines!.isEmpty) {
                            return const ListTile(
                              title: Text('No invoice lines found.'),
                            );
                          }

                          return _buildInvoiceLine(invoiceLines, context);
                        },
                      ),
                    ],
                  ))
              .toList(),
        ),
      );

  /// Build the title for an invoice.
  Widget _buildInvoiceTitle(Invoice invoice) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('''
Invoice # ${invoice.id} Issued: ${formatDate(invoice.createdDate)}'''),
          if (invoice.invoiceNum != null) Text('''
Xero Invoice # ${invoice.invoiceNum}'''),
          HMBButton(
              label: 'Delete',
              onPressed: () async => areYouSure(
                  context: context,
                  title: 'Delete Invoice',
                  message: 'Are you sure you want to delete this invoice?',
                  onConfirmed: () async {
                    try {
                      await DaoInvoice().delete(invoice.id);
                      if (Strings.isNotBlank(invoice.invoiceNum)) {
                        await XeroApi().login();

                        await XeroApi().deleteInvoice(invoice);
                      }
                      await _refresh();
                      // ignore: avoid_catches_without_on_clauses
                    } catch (e) {
                      if (mounted) {
                        HMBToast.error(e.toString());
                      }
                    }
                  }))
        ],
      );

  /// Build an invoice line.
  Widget _buildInvoiceLine(
      List<InvoiceLine> invoiceLines, BuildContext context) {
    final visibleLines = invoiceLines
        .where((line) => line.status != LineStatus.noChargeHidden)
        .toList();
    return Column(
      children: visibleLines
          .map((line) => ListTile(
                title: Text(line.description),
                subtitle: Text(
                  '''Quantity: ${line.quantity}, Unit Price: ${line.unitPrice}, Status: ${line.status.toString().split('.').last}''',
                ),
                trailing: Text('Total: ${line.lineTotal}'),
                onTap: () async => _editInvoiceLine(context, line),
              ))
          .toList(),
    );
  }

  /// build the create invoice button
  FutureBuilderEx<bool> _buildCreateInvoiceButton() => FutureBuilderEx<bool>(
        future: _hasUnbilledItems,
        builder: (context, hasUnbilledItems) => HMBOneOf(
            condition: hasUnbilledItems!,
            onTrue: Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton(
                onPressed: _createInvoice,
                child: const Text('Create Invoice'),
              ),
            ),
            onFalse: const Text('No billalbe Items found')),
      );

  /// Edit an invoice line.
  Future<void> _editInvoiceLine(BuildContext context, InvoiceLine line) async {
    final editedLine = await showDialog<InvoiceLine>(
      context: context,
      builder: (context) => EditInvoiceLineDialog(line: line),
    );

    if (editedLine != null) {
      // Update the invoice line in the database
      await DaoInvoiceLine().update(editedLine);
      await DaoInvoice().recalculateTotal(editedLine.invoiceId);
      setState(() {
        // Refresh the invoice lines
        _invoices = DaoInvoice().getByJobId(widget.job.id);
      });
    }
  }
}

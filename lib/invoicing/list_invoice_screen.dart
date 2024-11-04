import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:strings/strings.dart';

import '../dao/dao_checklist_item.dart';
import '../dao/dao_invoice.dart';
import '../dao/dao_invoice_line.dart';
import '../dao/dao_invoice_line_group.dart';
import '../dao/dao_invoice_time_and_materials.dart';
import '../dao/dao_job.dart';
import '../dao/dao_time_entry.dart';
import '../entity/invoice.dart';
import '../entity/invoice_line.dart';
import '../entity/invoice_line_group.dart';
import '../entity/job.dart';
import '../util/format.dart';
import '../util/money_ex.dart';
import '../widgets/async_state.dart';
import '../widgets/hmb_are_you_sure_dialog.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_one_of.dart';
import '../widgets/hmb_toast.dart';
import 'dialog_select_tasks.dart';
import 'edit_invoice_line_dialog.dart';
import 'generate_invoice_pdf_dialog.dart';
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

class _InvoiceListScreenState extends AsyncState<InvoiceListScreen, void> {
  late Future<List<Invoice>> _invoices;
  late Future<bool> _hasUnbilledItems;
  late XeroApi _xeroApi;
  late Job job;

  @override
  Future<void> asyncInitState() async {
    /// make certain we always have the latest copy of the job.
    job = (await DaoJob().getById(widget.job.id))!;
    // ignore: discarded_futures
    _invoices = DaoInvoice().getByJobId(job.id);
    _hasUnbilledItems = hasBillableItems();
  }

  Future<bool> hasBillableItems() async {
    final hasBillableTasks = await DaoJob().hasBillableTasks(job);
    final hasBillableBookingFee = await DaoJob().hasBillableBookingFee(job);

    return Future.value(hasBillableTasks || hasBillableBookingFee);
  }

  Future<void> _createInvoice() async {
    if (job.hourlyRate == MoneyEx.zero) {
      HMBToast.error('Hourly rate must be set for job ${job.summary}');
      return;
    }

    if ((await DaoTimeEntry().getActiveEntry()) != null) {
      HMBToast.error('Cannot create an invoice while a Task timer is active');
      return;
    }

    if (mounted) {
      final invoiceOptions =
          await DialogTaskSelection.showInvoice(context: context, job: job);

      if (invoiceOptions != null) {
        try {
          if (invoiceOptions.selectedTaskIds.isNotEmpty ||
              invoiceOptions.billBookingFee) {
            await createTimeAndMaterialsInvoice(
                job, invoiceOptions.selectedTaskIds,
                groupByTask: invoiceOptions.groupByTask,
                billBookingFee: invoiceOptions.billBookingFee);

            await _refresh();
          } else {
            HMBToast.info('''
You must select at least one Task or the Booking Fee to invoice''');
          }
          // ignore: avoid_catches_without_on_clauses
        } catch (e) {
          HMBToast.error('Failed to create invoice: $e',
              acknowledgmentRequired: true);
        }

        await _refresh();
      }
    }
  }

  Future<void> _uploadInvoiceToXero(Invoice invoice) async {
    try {
      _xeroApi = XeroApi();
      await _xeroApi.login();
      await DaoInvoice().uploadInvoiceToXero(invoice, _xeroApi);
      await _refresh();
      if (mounted) {
        HMBToast.info('Invoice uploaded to Xero successfully');
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e, st) {
      await Sentry.captureException(e,
          stackTrace: st, hint: Hint.withMap({'hint': 'UploadInvoiceToXero'}));
      if (mounted) {
        HMBToast.error('Failed to upload invoice: $e',
            acknowledgmentRequired: true);
      }
    }
  }

  Future<void> _refresh() async {
    job = (await DaoJob().getById(job.id))!;
    _invoices = DaoInvoice().getByJobId(job.id);
    _hasUnbilledItems = hasBillableItems();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Invoices for Job: ${widget.job.summary}'),
        ),
        body: FutureBuilderEx(
            future: initialised,
            builder: (context, _) => Column(
                  children: [
                    _buildCreateInvoiceButton(),
                    _buildInvoiceList(),
                  ],
                )),
      );

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
              child: Row(
                children: [
                  GenerateInvoicePdfDialog(
                      context: context,
                      mounted: mounted,
                      widget: widget,
                      invoice: invoice),
                  ElevatedButton(
                      onPressed: () async => _uploadOrSendInvoice(invoice),
                      child: _buildXeroButton(invoice)),
                ],
              ),
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

  Future<void> _uploadOrSendInvoice(Invoice invoice) async {
    if (Strings.isBlank(invoice.invoiceNum)) {
      await _uploadInvoiceToXero(invoice);
    } else {
      await _sendInvoiceFromXero(invoice);
    }
  }

  Future<void> _sendInvoiceFromXero(Invoice invoice) async {
    try {
      _xeroApi = XeroApi();
      await _xeroApi.login();
      await _xeroApi.sendInvoice(invoice);
      await _refresh();
      if (mounted) {
        HMBToast.info('Invoice sent from Xero successfully');
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      if (mounted) {
        HMBToast.error('Failed to send invoice: $e',
            acknowledgmentRequired: true);
      }
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
    final visibleLines = invoiceLines.toList();
    return Column(
      children: visibleLines
          .map((line) => ListTile(
                title: Text(line.description),
                subtitle: Text(
                  '''Quantity: ${line.quantity}, Unit Price: ${line.unitPrice}, Status: ${line.status.toString().split('.').last}''',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total: ${line.lineTotal}'),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async => _confirmAndDeleteInvoiceLine(line),
                    ),
                  ],
                ),
                onTap: () async => _editInvoiceLine(context, line),
              ))
          .toList(),
    );
  }

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
            onFalse: const Text('No billable Items found')),
      );

  Future<void> _confirmAndDeleteInvoiceLine(InvoiceLine line) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice Line'),
        content: Text('''
Are you sure you want to delete this invoice line?

Details:
Description: ${line.description}
Quantity: ${line.quantity}
Total: ${line.lineTotal}'''),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        // Mark source item as not billed
        if (line.invoiceLineGroupId != null) {
          await DaoCheckListItem().markNotBilled(line.id);
          await DaoTimeEntry().markAsNotbilled(line.id);
        }

        // Delete the invoice line
        await DaoInvoiceLine().delete(line.id);

        // Check if the line group is empty and delete if necessary
        final remainingLines = await DaoInvoiceLine()
            .getByInvoiceLineGroupId(line.invoiceLineGroupId!);

        if (remainingLines.isEmpty) {
          await DaoInvoiceLineGroup().delete(line.invoiceLineGroupId!);
        }

        // Recalculate the invoice total
        await DaoInvoice().recalculateTotal(line.invoiceId);

        await _refresh();
        // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        HMBToast.error('Failed to delete invoice line: $e',
            acknowledgmentRequired: true);
      }
    }
  }

  /// Edit an invoice line.
  Future<void> _editInvoiceLine(BuildContext context, InvoiceLine line) async {
    final editedLine = await showDialog<InvoiceLine>(
      context: context,
      builder: (context) => EditInvoiceLineDialog(line: line),
    );

    if (editedLine != null) {
      await DaoInvoiceLine().update(editedLine);
      await DaoInvoice().recalculateTotal(editedLine.invoiceId);
      setState(() {
        _invoices = DaoInvoice().getByJobId(job.id);
      });
    }
  }
}

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:strings/strings.dart';

import '../../api/xero/xero_api.dart';
import '../../dao/dao_contact.dart';
import '../../dao/dao_invoice.dart';
import '../../dao/dao_invoice_line.dart';
import '../../dao/dao_invoice_line_group.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_task_item.dart';
import '../../dao/dao_time_entry.dart';
import '../../entity/invoice_line.dart';
import '../../util/format.dart';
import '../dialog/hmb_are_you_sure_dialog.dart';
import '../widgets/async_state.dart';
import '../widgets/hmb_toast.dart';
import 'edit_invoice_line_dialog.dart';
import 'generate_invoice_pdf_button.dart';
import 'invoice_details.dart';

class InvoiceEditScreen extends StatefulWidget {
  const InvoiceEditScreen({required this.invoiceDetails, super.key});

  final InvoiceDetails invoiceDetails;

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends AsyncState<InvoiceEditScreen, void> {
  final XeroApi _xeroApi = XeroApi();
  late final int invoiceId;
  late Future<InvoiceDetails> _invoiceDetails;

  @override
  Future<void> asyncInitState() async {
    invoiceId = widget.invoiceDetails.invoice.id;
    await _reloadInvoice();
  }

  Future<void> _reloadInvoice() async {
    // ignore: discarded_futures
    _invoiceDetails = InvoiceDetails.load(invoiceId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilderEx<InvoiceDetails>(
        future: _invoiceDetails,
        waitingBuilder: (_) => const Center(child: CircularProgressIndicator()),
        builder: (context, details) {
          if (details == null) {
            return const Center(child: Text('No invoice details found.'));
          }

          final invoice = details.invoice;
          final job = details.job;
          final customer = details.customer;
          final lineGroups = details.lineGroups;

          // Show all details without expansions
          return Scaffold(
            appBar: AppBar(
              title: Text('Edit Invoice #${invoice.id}'),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice #${invoice.id} Issued: ${formatDate(invoice.createdDate)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text('Customer: ${customer?.name ?? "N/A"}'),
                  Text('Job: ${job.summary} #${job.id}'),
                  Text('Total: ${invoice.totalAmount}'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _uploadInvoiceToXero,
                        child: const Text('Upload to Xero'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _deleteInvoice,
                        child: const Text('Delete Invoice'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GenerateInvoicePdfButton(
                      context: context, mounted: mounted, invoice: invoice),
                  const SizedBox(height: 16),
                  // Show all line groups and lines inline
                  for (final group in lineGroups) ...[
                    Text(group.group.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (final line in group.lines) ...[
                      ListTile(
                        title: Text(line.description),
                        subtitle: Text(
                          'Qty: ${line.quantity}, Unit: ${line.unitPrice}, Status: ${line.status.toString().split('.').last}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Total: ${line.lineTotal}'),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async =>
                                  _editInvoiceLine(context, line),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async => _deleteInvoiceLine(line),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          );
        },
      );

  Future<void> _deleteInvoice() async {
    await areYouSure(
      context: context,
      title: 'Delete Confirmation',
      message: 'Are you sure you want to delete this invoice?',
      onConfirmed: () async {
        try {
          final invoiceDetails = await _invoiceDetails;
          final sent = invoiceDetails.invoice.sent;
          await DaoInvoice().delete(invoiceDetails.invoice.id);
          if (Strings.isNotBlank(invoiceDetails.invoice.invoiceNum)) {
            await _xeroApi.login();
            if (sent) {
              HMBToast.error(
                  'This invoice has been sent to the customer and cannot be deleted');
            } else {
              await _xeroApi.deleteInvoice(invoiceDetails.invoice);
            }
          }
          if (mounted) {
            Navigator.pop(context); // Close after deletion
          }
        } catch (e) {
          HMBToast.error('Failed to delete invoice: $e');
        }
      },
    );
  }

  Future<void> _uploadInvoiceToXero() async {
    try {
      final invoice = (await _invoiceDetails).invoice;
      final job = await DaoJob().getById(invoice.jobId);
      final contact = await DaoContact().getPrimaryForCustomer(job!.customerId);
      if (contact == null) {
        HMBToast.error('You must first add a Contact to the Customer');
        return;
      }

      if (Strings.isBlank(contact.emailAddress)) {
        HMBToast.error("The customer's primary contact must have an email.");
        return;
      }

      await _xeroApi.login();
      await DaoInvoice().uploadInvoiceToXero(invoice, _xeroApi);
      HMBToast.info('Invoice uploaded to Xero successfully');
      await _reloadInvoice();
      setState(() {});
    } catch (e, st) {
      await Sentry.captureException(e,
          stackTrace: st, hint: Hint.withMap({'hint': 'UploadInvoiceToXero'}));
      HMBToast.error('Failed to upload invoice: $e',
          acknowledgmentRequired: true);
    }
  }

  Future<void> _editInvoiceLine(BuildContext context, InvoiceLine line) async {
    final editedLine = await showDialog<InvoiceLine>(
      context: context,
      builder: (context) => EditInvoiceLineDialog(line: line),
    );

    if (editedLine != null) {
      await DaoInvoiceLine().update(editedLine);
      await DaoInvoice().recalculateTotal(editedLine.invoiceId);
      await _reloadInvoice();
      setState(() {});
    }
  }

  Future<void> _deleteInvoiceLine(InvoiceLine line) async {
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
        await DaoTaskItem().markNotBilled(line.id);
        await DaoTimeEntry().markAsNotbilled(line.id);

        await DaoInvoiceLine().delete(line.id);

        final remainingLines = await DaoInvoiceLine()
            .getByInvoiceLineGroupId(line.invoiceLineGroupId);

        if (remainingLines.isEmpty) {
          await DaoInvoiceLineGroup().delete(line.invoiceLineGroupId);
        }

        await DaoInvoice().recalculateTotal(line.invoiceId);
        await _reloadInvoice();
        setState(() {});
      } catch (e) {
        HMBToast.error('Failed to delete invoice line: $e',
            acknowledgmentRequired: true);
      }
    }
  }
}
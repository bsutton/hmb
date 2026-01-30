/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:strings/strings.dart';

import '../../api/accounting/accounting_adaptor.dart';
import '../../api/external_accounting.dart';
import '../../dao/dao_contact.dart';
import '../../dao/dao_invoice.dart';
import '../../dao/dao_invoice_line.dart';
import '../../dao/dao_invoice_line_group.dart';
import '../../dao/dao_task_item.dart';
import '../../dao/dao_time_entry.dart';
import '../../entity/invoice_line.dart';
import '../../util/dart/format.dart';
import '../dialog/hmb_comfirm_delete_dialog.dart';
import '../widgets/blocking_ui.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/icons/hmb_delete_icon.dart';
import '../widgets/icons/hmb_edit_icon.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/layout/surface.dart';
import 'edit_invoice_line_dialog.dart';
import 'invoice_details.dart';
import 'invoice_send_button.dart';

class InvoiceEditScreen extends StatefulWidget {
  final InvoiceDetails invoiceDetails;

  const InvoiceEditScreen({required this.invoiceDetails, super.key});

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends DeferredState<InvoiceEditScreen> {
  late final int invoiceId;
  late Future<InvoiceDetails> _invoiceDetails;

  @override
  Future<void> asyncInitState() async {
    invoiceId = widget.invoiceDetails.invoice.id;
    await _reloadInvoice();
  }

  Future<void> _reloadInvoice() async {
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
        appBar: AppBar(title: Text('Edit Invoice #${invoice.id}')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Surface(
            elevation: SurfaceElevation.e6,
            child: HMBColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '''Invoice #${invoice.id} Issued: ${formatDate(invoice.createdDate)}''',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text('Customer: ${customer?.name ?? "N/A"}'),
                Text('Job: ${job.summary} #${job.id}'),
                Text('Total: ${invoice.totalAmount}'),
                HMBRow(
                  children: [
                    HMBButton(
                      label: 'Upload to Xero',
                      hint: 'Upload the invoice to Xero',
                      onPressed: () {
                        BlockingUI().run(() async {
                          await _uploadInvoiceToXero();
                        }, label: 'Uploading Invoice');
                      },
                    ),
                    BuildSendButton(
                      context: context,
                      mounted: mounted,
                      invoice: invoice,
                    ),
                  ],
                ),
                // Show all line groups and lines inline
                for (final group in lineGroups) ...[
                  Text(
                    group.group.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final line in group.lines) ...[
                    HMBListCard(
                      title: line.description,
                      actions: [
                        HMBEditIcon(
                          onPressed: () => _editInvoiceLine(context, line),
                          hint: 'Edit Invoice Line',
                        ),
                        HMBDeleteIcon(
                          onPressed: () => _deleteInvoiceLine(line),
                          hint: 'Delete Invoice Line',
                        ),
                      ],
                      children: [
                        Text(
                          '''Qty: ${line.quantity}, Unit: ${line.unitPrice}, Status: ${line.status.description}''',
                        ),
                        Text('Total: ${line.lineTotal}'),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      );
    },
  );

  Future<void> _uploadInvoiceToXero() async {
    if (!(await ExternalAccounting().isEnabled())) {
      HMBToast.info(
        'You must first enable the Xero Integration via System | Intgration',
      );
      return;
    }
    try {
      final invoice = (await _invoiceDetails).invoice;
      final contact = await DaoContact().getById(invoice.billingContactId);
      if (contact == null) {
        HMBToast.error('You must first add a Contact to the Customer');
        return;
      }

      if (Strings.isBlank(contact.emailAddress)) {
        HMBToast.error("The customer's billing contact must have an email.");
        return;
      }

      final adaptor = AccountingAdaptor.get();

      await adaptor.login();
      await adaptor.uploadInvoice(invoice);
      HMBToast.info('Invoice uploaded to Xero successfully');
      await _reloadInvoice();
      setState(() {});
    } catch (e, st) {
      if (!e.toString().contains('You must provide an email address for')) {
        unawaited(
          Sentry.captureException(
            e,
            stackTrace: st,
            hint: Hint.withMap({'hint': 'UploadInvoiceToXero'}),
          ),
        );
      }
      HMBToast.error(
        'Failed to upload invoice: $e',
        acknowledgmentRequired: true,
      );
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
    await showConfirmDeleteDialog(
      nameSingular: 'Invoice line',
      context: context,
      child: Text('''
Are you sure you want to delete this invoice line?

Details:
Description: ${line.description}
Quantity: ${line.quantity}
Total: ${line.lineTotal}'''),
      onConfirmed: () => _doDeleteInvoiceLine(line),
    );
  }

  Future<void> _doDeleteInvoiceLine(InvoiceLine line) async {
    try {
      await DaoTaskItem().markNotBilled(line.id);
      await DaoTimeEntry().markAsNotbilled(line.id);

      await DaoInvoiceLine().delete(line.id);

      final remainingLines = await DaoInvoiceLine().getByInvoiceLineGroupId(
        line.invoiceLineGroupId,
      );

      if (remainingLines.isEmpty) {
        await DaoInvoiceLineGroup().delete(line.invoiceLineGroupId);
      }

      await DaoInvoice().recalculateTotal(line.invoiceId);
      await _reloadInvoice();
      setState(() {});
    } catch (e) {
      HMBToast.error(
        'Failed to delete invoice line: $e',
        acknowledgmentRequired: true,
      );
    }
  }
}

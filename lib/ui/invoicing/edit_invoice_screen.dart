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
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:strings/strings.dart';

import '../../api/accounting/accounting_adaptor.dart';
import '../../api/external_accounting.dart';
import '../../dao/dao_invoice.dart';
import '../../dao/dao_invoice_line.dart';
import '../../dao/dao_invoice_line_group.dart';
import '../../dao/dao_task_item.dart';
import '../../dao/dao_time_entry.dart';
import '../../dao/debtor_ledger_service.dart';
import '../../dao/invoice_billing_contact.dart';
import '../../dao/join_adaptors/join_adaptor_customer_contact.dart';
import '../../entity/contact.dart';
import '../../entity/customer.dart';
import '../../entity/invoice.dart';
import '../../entity/invoice_line.dart';
import '../../util/dart/exceptions.dart';
import '../../util/dart/format.dart';
import '../../util/dart/money_ex.dart';
import '../crud/contact/edit_contact_screen.dart';
import '../dialog/hmb_comfirm_delete_dialog.dart';
import '../quoting/select_billing_contact_dialog.dart';
import '../widgets/blocking_ui.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/icons/hmb_delete_icon.dart';
import '../widgets/icons/hmb_edit_icon.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/layout/surface.dart';
import 'apply_payment_to_invoice_dialog.dart';
import 'edit_invoice_line_dialog.dart';
import 'invoice_details.dart';
import 'invoice_send_button.dart';
import 'record_invoice_adjustment_dialog.dart';
import 'record_invoice_payment_dialog.dart';
import 'void_invoice_dialog.dart';
import 'write_off_invoice_balance_dialog.dart';

class InvoiceEditScreen extends StatefulWidget {
  final InvoiceDetails invoiceDetails;

  const InvoiceEditScreen({required this.invoiceDetails, super.key});

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

enum _BillingContactFix { edit, change }

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
      final readOnlyInvoice = invoice.isExternallyDeletedOrVoided;
      final canChangeInvoice =
          !readOnlyInvoice && !invoice.isUploaded() && !invoice.sent;

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
                  '''Invoice #${invoice.id} - ${formatDate(invoice.createdDate)}''',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text('Customer: ${customer?.name ?? "N/A"}'),
                Text('Job: ${job.summary} #${job.id}'),
                _buildBillingContact(details, canChangeInvoice),
                if (Strings.isNotBlank(invoice.voidDescription))
                  Text('Void description: ${invoice.voidDescription}'),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Payment tracking: '
                      '${_paymentManagementLabel(invoice)}',
                    ),
                    Text(
                      'Accounting sync: '
                      '${_syncStatusLabel(invoice.externalSyncStatus)}',
                    ),
                  ],
                ),
                _buildLedgerSummary(details),
                if (invoice.paymentSource == InvoicePaymentSource.unknown)
                  const Text(
                    'This invoice needs payment tracking review. Convert it '
                    'to manual tracking if it is no longer managed in Xero.',
                  ),
                if (!readOnlyInvoice)
                  FutureBuilderEx<bool>(
                    future: ExternalAccounting().isEnabled(),
                    builder: (context, accountingEnabled) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!invoice.isUploaded() && !invoice.isManagedLocally)
                          HMBButton(
                            label: 'Upload to Xero',
                            hint: 'Upload the invoice to Xero',
                            onPressed: () {
                              BlockingUI().run(() async {
                                await _uploadInvoiceToXero();
                              }, label: 'Uploading Invoice');
                            },
                          ),
                        if (invoice.canConvertToManualTracking)
                          HMBButton(
                            label: 'Convert to Manual Tracking',
                            hint:
                                'Switch this invoice to manual payment '
                                'tracking',
                            onPressed: () async {
                              await _convertToManualTracking();
                            },
                          ),
                        if (_canRecordPayment(details))
                          HMBButton(
                            label: 'Record Payment',
                            hint: 'Record a payment against this invoice',
                            onPressed: () async {
                              await _recordPayment(details);
                            },
                          ),
                        if (_canRecordAdjustment(details))
                          HMBButton(
                            label: 'Add Adjustment',
                            hint: 'Record an adjustment against this invoice',
                            onPressed: () async {
                              await _recordAdjustment(details);
                            },
                          ),
                        if (_canWriteOffSmallBalance(details))
                          HMBButton(
                            label: 'Write Off Small Balance',
                            hint: 'Write off a small unpaid invoice balance',
                            onPressed: () async {
                              await _writeOffBalance(
                                details,
                                smallBalance: true,
                              );
                            },
                          ),
                        if (_canWriteOffBalance(details) &&
                            !_canWriteOffSmallBalance(details))
                          HMBButton(
                            label: 'Write Off',
                            hint: 'Write off this unpaid invoice balance',
                            onPressed: () async {
                              await _writeOffBalance(details);
                            },
                          ),
                        if (_canVoidInvoice(details))
                          HMBButton(
                            label: 'Void Invoice',
                            hint: 'Void this sent invoice',
                            onPressed: () async {
                              if (await promptAndVoidInvoice(
                                context: context,
                                invoice: invoice,
                              )) {
                                await _reloadInvoice();
                                if (!mounted) {
                                  return;
                                }
                                setState(() {});
                              }
                            },
                          ),
                        if (canChangeInvoice)
                          HMBButton(
                            label: 'Add Discount',
                            hint: 'Add a discount line to this invoice.',
                            onPressed: () async {
                              await _promptAddDiscount();
                            },
                          ),
                        BuildSendButton(
                          context: context,
                          mounted: mounted,
                          invoice: invoice,
                        ),
                      ],
                    ),
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
                      actions: canChangeInvoice
                          ? [
                              HMBEditIcon(
                                onPressed: () =>
                                    _editInvoiceLine(context, line),
                                hint: 'Edit Invoice Line',
                              ),
                              HMBDeleteIcon(
                                onPressed: () => _deleteInvoiceLine(line),
                                hint: 'Delete Invoice Line',
                              ),
                            ]
                          : [],
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

  String _syncStatusLabel(InvoiceExternalSyncStatus status) => switch (status) {
    InvoiceExternalSyncStatus.none => 'Not synced',
    InvoiceExternalSyncStatus.linked => 'Linked to Xero',
    InvoiceExternalSyncStatus.deleted => 'Deleted in Xero',
    InvoiceExternalSyncStatus.voided => 'Voided in Xero',
  };

  Widget _buildBillingContact(InvoiceDetails details, bool canChangeInvoice) {
    final resolved = details.billingContact;
    final contact = resolved.contact;
    final jobContact = details.jobBillingContact;
    final contactName = contact?.fullname.trim();
    final hasMismatch =
        contact != null && jobContact != null && contact.id != jobContact.id;
    final jobContactEmail =
        jobContact != null && Strings.isNotBlank(jobContact.bestEmail)
        ? jobContact.bestEmail
        : 'no email';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Surface(
        elevation: SurfaceElevation.e1,
        child: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Billing contact',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              contact == null || contactName!.isEmpty
                  ? 'No billing contact selected'
                  : contactName,
            ),
            if (contact != null && resolved.hasEmail)
              Text(contact.bestEmail)
            else
              const Text(
                'No email address. Add an email or select another contact '
                'before sending or uploading this invoice.',
                style: TextStyle(color: Colors.red),
              ),
            if (resolved.source == InvoiceBillingContactSource.jobFallback)
              const Text('Currently inherited from the job.'),
            if (hasMismatch)
              Text(
                'Job billing contact: ${jobContact.fullname.trim()} '
                '($jobContactEmail)',
              ),
            if (canChangeInvoice)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  HMBButton(
                    label: 'Change Contact',
                    hint: 'Select the billing contact for this invoice',
                    onPressed: () => _changeBillingContact(details),
                  ),
                  if (contact != null)
                    HMBButton(
                      label: 'Edit Contact',
                      hint: 'Edit ${contact.fullname.trim()}',
                      onPressed: () => _editBillingContact(details, contact),
                    ),
                  if (jobContact != null &&
                      (hasMismatch ||
                          resolved.source ==
                              InvoiceBillingContactSource.jobFallback))
                    HMBButton(
                      label: 'Use Job Contact',
                      hint:
                          'Use ${jobContact.fullname.trim()} for this invoice',
                      onPressed: () =>
                          _saveBillingContact(details.invoice, jobContact),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeBillingContact(InvoiceDetails details) async {
    final customer = details.billingCustomer;
    if (customer == null) {
      HMBToast.error('The billing party does not have a customer record.');
      return;
    }
    final selected = await SelectBillingContactDialog.show(
      context,
      customer,
      details.billingContact.contact,
      null,
    );
    if (selected != null) {
      await _saveBillingContact(details.invoice, selected);
    }
  }

  Future<void> _editBillingContact(
    InvoiceDetails details,
    Contact contact,
  ) async {
    final customer = details.billingCustomer;
    if (customer == null) {
      HMBToast.error('The billing party does not have a customer record.');
      return;
    }
    await Navigator.of(context).push<Contact>(
      MaterialPageRoute<Contact>(
        builder: (context) => ContactEditScreen<Customer>(
          parent: customer,
          daoJoin: JoinAdaptorCustomerContact(),
          contact: contact,
        ),
      ),
    );
    await _reloadInvoiceAndRefresh();
  }

  Future<void> _saveBillingContact(Invoice invoice, Contact contact) async {
    await BlockingUI().runAndWait(
      () => DaoInvoice().updateBillingContact(invoice.id, contact.id),
      label: 'Updating billing contact',
    );
    await _reloadInvoiceAndRefresh();
    HMBToast.info('Invoice billing contact updated.');
  }

  Future<void> _reloadInvoiceAndRefresh() async {
    await _reloadInvoice();
    if (mounted) {
      setState(() {});
    }
  }

  String _paymentManagementLabel(Invoice invoice) {
    if (invoice.isManagedLocally) {
      return 'Managed locally';
    }
    return switch (invoice.paymentSource) {
      InvoicePaymentSource.manual => 'Managed locally',
      InvoicePaymentSource.xero => 'Managed by Xero',
      InvoicePaymentSource.unknown => 'Needs review',
    };
  }

  Widget _buildLedgerSummary(InvoiceDetails details) {
    final ledger = details.ledger;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Surface(
        elevation: SurfaceElevation.e1,
        child: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment summary',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Invoice total: ${ledger.total}'),
                Text('Paid: ${ledger.paid}'),
                Text('Credited: ${ledger.credited}'),
                Text('Adjusted: ${ledger.adjusted}'),
                Text('Balance: ${ledger.balance}'),
                Text('Status: ${_ledgerStatusLabel(ledger.status)}'),
              ],
            ),
            if (_canApplyPayment(details))
              HMBButton(
                label: 'Allocate Payment',
                hint: 'Allocate an existing customer payment to this invoice',
                onPressed: () => _applyPayment(details),
              ),
            if (details.ledgerHistory.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'History',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final entry in details.ledgerHistory)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_ledgerHistoryIcon(entry.type), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _ledgerHistoryLabel(entry),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _ledgerStatusLabel(DebtorInvoiceStatus status) => switch (status) {
    DebtorInvoiceStatus.draft => 'Draft',
    DebtorInvoiceStatus.sent => 'Outstanding',
    DebtorInvoiceStatus.partPaid => 'Part paid',
    DebtorInvoiceStatus.paid => 'Paid',
    DebtorInvoiceStatus.credited => 'Credited',
    DebtorInvoiceStatus.overpaid => 'Overpaid',
    DebtorInvoiceStatus.voided => 'Voided',
    DebtorInvoiceStatus.writtenOff => 'Written off',
  };

  IconData _ledgerHistoryIcon(InvoiceLedgerHistoryEntryType type) =>
      switch (type) {
        InvoiceLedgerHistoryEntryType.payment => Icons.payments,
        InvoiceLedgerHistoryEntryType.credit => Icons.assignment_return,
        InvoiceLedgerHistoryEntryType.adjustment => Icons.rule,
      };

  String _ledgerHistoryLabel(InvoiceLedgerHistoryEntry entry) {
    final detail = Strings.isBlank(entry.detail) ? '' : ' - ${entry.detail}';
    if (entry.type == InvoiceLedgerHistoryEntryType.payment) {
      return '${entry.title}: ${entry.amount}$detail - Allocated: '
          '${formatDate(entry.date, format: 'j M Y')}';
    }
    return '${formatDate(entry.date)} ${entry.title}: ${entry.amount}$detail';
  }

  bool _canRecordPayment(InvoiceDetails details) =>
      details.invoice.isManagedLocally &&
      !details.invoice.isExternallyDeletedOrVoided &&
      details.ledger.balance.isPositive;

  bool _canApplyPayment(InvoiceDetails details) =>
      !details.invoice.isExternallyDeletedOrVoided &&
      details.ledger.balance.isPositive;

  bool _canRecordAdjustment(InvoiceDetails details) =>
      details.invoice.isManagedLocally &&
      !details.invoice.isExternallyDeletedOrVoided;

  bool _canWriteOffSmallBalance(InvoiceDetails details) =>
      _canWriteOffBalance(details) &&
      details.ledger.balance <= MoneyEx.fromInt(100);

  bool _canWriteOffBalance(InvoiceDetails details) =>
      details.invoice.isManagedLocally &&
      !details.invoice.isExternallyDeletedOrVoided &&
      details.ledger.balance.isPositive;

  bool _canVoidInvoice(InvoiceDetails details) =>
      details.invoice.canVoid &&
      details.ledger.isOutstanding &&
      details.ledger.paid.isZero &&
      details.ledger.credited.isZero &&
      details.ledger.adjusted.isZero;

  Future<void> _convertToManualTracking() async {
    await DaoInvoice().convertToManualTracking(invoiceId);
    await _reloadInvoice();
    if (!mounted) {
      return;
    }
    HMBToast.info('Invoice converted to manual tracking');
    setState(() {});
  }

  Future<void> _recordPayment(InvoiceDetails details) async {
    final request = await showRecordInvoicePaymentDialog(
      context: context,
      balance: details.ledger.balance,
    );
    if (request == null) {
      return;
    }
    try {
      await DebtorLedgerService().recordPayment(
        invoiceId: details.invoice.id,
        amount: request.amount,
        paymentMethod: request.paymentMethod,
        reference: request.reference,
        notes: request.notes,
      );
      await _reloadInvoice();
      if (!mounted) {
        return;
      }
      HMBToast.info('Payment recorded');
      setState(() {});
    } catch (e) {
      HMBToast.error(
        'Failed to record payment: $e',
        acknowledgmentRequired: true,
      );
    }
  }

  Future<void> _applyPayment(InvoiceDetails details) async {
    final customerId = details.job.customerId;
    if (customerId == null) {
      HMBToast.error('The invoice job does not have a customer.');
      return;
    }
    final ledgerService = DebtorLedgerService();
    final payments = await ledgerService.unallocatedPaymentsForCustomer(
      customerId,
    );
    if (!mounted) {
      return;
    }
    final request = await showApplyPaymentToInvoiceDialog(
      context: context,
      payments: payments,
      balance: details.ledger.balance,
    );
    if (request == null) {
      return;
    }
    try {
      if (request.recordsNewPayment) {
        final payment = await ledgerService.recordUnallocatedPayment(
          customerId: customerId,
          contactId: details.invoice.billingContactId,
          amount: request.newPaymentAmount!,
          paymentDate: request.allocatedDate,
          paymentMethod: request.paymentMethod,
          reference: request.reference,
          notes: request.notes,
        );
        await ledgerService.applyPaymentToInvoice(
          paymentId: payment.id,
          invoiceId: details.invoice.id,
          amount: request.amount,
          allocatedDate: request.allocatedDate,
        );
      } else {
        await ledgerService.applyPaymentToInvoice(
          paymentId: request.paymentId!,
          invoiceId: details.invoice.id,
          amount: request.amount,
          allocatedDate: request.allocatedDate,
        );
      }
      await _reloadInvoice();
      if (!mounted) {
        return;
      }
      HMBToast.info(
        request.recordsNewPayment ? 'Payment recorded' : 'Payment applied',
      );
      setState(() {});
    } catch (e) {
      HMBToast.error(
        'Failed to apply payment: $e',
        acknowledgmentRequired: true,
      );
    }
  }

  Future<void> _recordAdjustment(InvoiceDetails details) async {
    final request = await showRecordInvoiceAdjustmentDialog(
      context: context,
      balance: details.ledger.balance,
    );
    if (request == null) {
      return;
    }
    try {
      await DebtorLedgerService().addJournalAdjustment(
        invoiceId: details.invoice.id,
        amount: request.amount,
        reason: request.reason,
        adjustmentType: request.adjustmentType,
        notes: request.notes,
      );
      await _reloadInvoice();
      if (!mounted) {
        return;
      }
      HMBToast.info('Adjustment recorded');
      setState(() {});
    } catch (e) {
      HMBToast.error(
        'Failed to record adjustment: $e',
        acknowledgmentRequired: true,
      );
    }
  }

  Future<void> _writeOffBalance(
    InvoiceDetails details, {
    bool smallBalance = false,
  }) async {
    final request = await showWriteOffInvoiceBalanceDialog(
      context: context,
      balance: details.ledger.balance,
      smallBalance: smallBalance,
    );
    if (request == null) {
      return;
    }
    try {
      if (request.smallBalanceOnly) {
        await DebtorLedgerService().writeOffSmallBalance(
          invoiceId: details.invoice.id,
          reason: request.reason,
        );
      } else {
        await DebtorLedgerService().writeOffInvoiceBalance(
          invoiceId: details.invoice.id,
          reason: request.reason,
        );
      }
      await _reloadInvoice();
      if (!mounted) {
        return;
      }
      HMBToast.info('Invoice balance written off');
      setState(() {});
    } catch (e) {
      HMBToast.error(
        'Failed to write off invoice balance: $e',
        acknowledgmentRequired: true,
      );
    }
  }

  Future<void> _uploadInvoiceToXero() async {
    if (!(await ExternalAccounting().isEnabled())) {
      HMBToast.info(
        'You must first enable the Xero Integration via System | Intgration',
      );
      return;
    }
    try {
      final details = await _invoiceDetails;
      final invoice = details.invoice;
      if (invoice.isUploaded()) {
        HMBToast.error('This invoice has already been uploaded to Xero.');
        return;
      }
      try {
        await _prepareBillingContactForDelivery(invoice);
      } on InvoiceException catch (error) {
        await _showBillingContactProblem(details, error.message);
        return;
      }

      final adaptor = AccountingAdaptor.get();

      await adaptor.login();
      await adaptor.uploadInvoice(invoice);
      if (!mounted) {
        return;
      }
      HMBToast.info('Invoice uploaded to Xero successfully');
      await _reloadInvoice();
      if (!mounted) {
        return;
      }
      setState(() {});
    } catch (e, st) {
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: st,
          hint: Hint.withMap({'hint': 'UploadInvoiceToXero'}),
        ),
      );
      HMBToast.error(
        'Failed to upload invoice: $e',
        acknowledgmentRequired: true,
      );
    }
  }

  Future<Contact> _prepareBillingContactForDelivery(Invoice invoice) async {
    final resolved = await resolveInvoiceBillingContact(invoice);
    final contact = await requireInvoiceBillingContact(invoice);
    if (resolved.source == InvoiceBillingContactSource.jobFallback &&
        invoice.canChangeBillingContact) {
      await DaoInvoice().updateBillingContact(invoice.id, contact.id);
      invoice.billingContactId = contact.id;
    }
    return contact;
  }

  Future<void> _showBillingContactProblem(
    InvoiceDetails details,
    String message,
  ) async {
    if (!mounted) {
      return;
    }
    final contact = details.billingContact.contact;
    final action = await showDialog<_BillingContactFix>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Billing contact needs attention'),
        content: Text(message),
        actions: [
          HMBButton(
            label: 'Cancel',
            hint: 'Return to the invoice',
            onPressed: () => Navigator.of(context).pop(),
          ),
          if (contact != null)
            HMBButton(
              label: 'Edit Contact',
              hint: 'Add or change the billing contact email',
              onPressed: () =>
                  Navigator.of(context).pop(_BillingContactFix.edit),
            ),
          HMBButton(
            label: 'Change Contact',
            hint: 'Select another billing contact',
            onPressed: () =>
                Navigator.of(context).pop(_BillingContactFix.change),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    switch (action) {
      case _BillingContactFix.edit when contact != null:
        await _editBillingContact(details, contact);
      case _BillingContactFix.change:
        await _changeBillingContact(details);
      case null:
      case _BillingContactFix.edit:
        return;
    }
  }

  Future<void> _editInvoiceLine(BuildContext context, InvoiceLine line) async {
    final invoice = (await _invoiceDetails).invoice;
    if (invoice.isUploaded() ||
        invoice.sent ||
        invoice.isExternallyDeletedOrVoided) {
      HMBToast.error('Sent, uploaded or voided invoices cannot be edited.');
      return;
    }
    if (!context.mounted) {
      return;
    }

    final editedLine = await showDialog<InvoiceLine>(
      context: context,
      builder: (context) => EditInvoiceLineDialog(line: line),
    );

    if (editedLine != null) {
      await DaoInvoiceLine().update(editedLine);
      await DaoInvoice().recalculateTotal(editedLine.invoiceId);
      await _reloadInvoice();
      if (!mounted) {
        return;
      }
      setState(() {});
    }
  }

  Future<void> _deleteInvoiceLine(InvoiceLine line) async {
    final invoice = (await _invoiceDetails).invoice;
    if (invoice.isUploaded() ||
        invoice.sent ||
        invoice.isExternallyDeletedOrVoided) {
      HMBToast.error('Sent, uploaded or voided invoices cannot be edited.');
      return;
    }
    if (!mounted) {
      return;
    }

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
      if (!mounted) {
        return;
      }
      setState(() {});
    } catch (e) {
      HMBToast.error(
        'Failed to delete invoice line: $e',
        acknowledgmentRequired: true,
      );
    }
  }

  Future<void> _promptAddDiscount() async {
    final details = await _invoiceDetails;
    if (details.invoice.isUploaded() ||
        details.invoice.sent ||
        details.invoice.isExternallyDeletedOrVoided) {
      HMBToast.error('Sent, uploaded or voided invoices cannot be changed.');
      return;
    }

    final descriptionController = TextEditingController(text: 'Discount');
    final amountController = TextEditingController();
    if (!mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final amount = MoneyEx.tryParse(amountController.text);
    if (!amount.isPositive) {
      HMBToast.error('Discount amount must be greater than zero.');
      return;
    }

    try {
      await DaoInvoice().addDiscountLine(
        invoice: details.invoice,
        amount: amount,
        description: descriptionController.text.trim().isEmpty
            ? 'Discount'
            : descriptionController.text.trim(),
      );
      await _reloadInvoice();
      if (!mounted) {
        return;
      }
      setState(() {});
    } catch (e) {
      HMBToast.error(
        'Failed to add discount: $e',
        acknowledgmentRequired: true,
      );
    }
  }
}

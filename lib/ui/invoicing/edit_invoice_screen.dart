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
import 'package:material_ui/material_ui.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:strings/strings.dart';

import '../../api/accounting/accounting_adaptor.dart';
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
import '../widgets/layout/hmb_spacing.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/layout/surface.dart';
import 'apply_payment_to_invoice_dialog.dart';
import 'edit_invoice_line_dialog.dart';
import 'invoice_accounting_state.dart';
import 'invoice_details.dart';
import 'invoice_discount_dialog.dart';
import 'invoice_editor_actions.dart';
import 'invoice_send_button.dart';
import 'quickbooks_export_screen.dart';
import 'record_invoice_adjustment_dialog.dart';
import 'void_invoice_dialog.dart';
import 'write_off_invoice_balance_dialog.dart';

class InvoiceEditScreen extends StatefulWidget {
  final InvoiceDetails invoiceDetails;
  final Future<InvoiceDetails> Function(int)? loadDetails;
  final Future<InvoiceAccountingState> Function(int)? loadAccounting;
  final Future<void> Function(Invoice)? prepareAccountingContact;
  final Future<void> Function()? accountingLogin;
  final Future<void> Function(Invoice)? accountingUpload;

  const InvoiceEditScreen({
    required this.invoiceDetails,
    this.loadDetails,
    this.loadAccounting,
    this.prepareAccountingContact,
    this.accountingLogin,
    this.accountingUpload,
    super.key,
  });

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

enum _BillingContactFix { edit, change }

class _InvoiceEditScreenState extends DeferredState<InvoiceEditScreen> {
  late final int invoiceId;
  late Future<InvoiceDetails> _invoiceDetails;
  var _accounting = const InvoiceAccountingState(
    destination: InvoiceAccountingDestination.none,
  );
  var _sendingToAccounting = false;
  Object? _loadError;
  var _accountingUnavailable = false;
  String? _accountingError;

  @override
  Future<void> asyncInitState() async {
    invoiceId = widget.invoiceDetails.invoice.id;
    await BlockingUI().runAndWait(_reloadInvoice, label: 'Opening invoice');
  }

  Future<void> _reloadInvoice() async {
    try {
      _invoiceDetails = (widget.loadDetails ?? InvoiceDetails.load)(invoiceId);
      await _invoiceDetails;
      _loadError = null;
    } catch (error) {
      // DeferredState must complete initialization even when a lookup fails.
      _loadError = error;
      return;
    }
    try {
      _accounting =
          await (widget.loadAccounting ?? InvoiceAccountingState.load)(
            invoiceId,
          );
      _accountingUnavailable = false;
      _accountingError = null;
    } catch (_) {
      _accountingUnavailable = true;
      _accountingError =
          'Could not load accounting settings. '
          'Local invoice actions are still available.';
    }
  }

  Widget _buildLoadError() => HMBFormList(
    children: [
      const Text('Could not load this invoice. Please try again.'),
      HMBButtonSecondary(
        label: 'Retry',
        hint: 'Reload invoice details',
        onPressed: () async {
          await BlockingUI().runAndWait(
            _reloadInvoice,
            label: 'Reloading invoice',
          );
          if (mounted) {
            setState(() {});
          }
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Invoice #${widget.invoiceDetails.invoice.id}')),
    body: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, _) => _buildLoadError(),
      builder: (_) => _loadError != null
          ? _buildLoadError()
          : BlockingUITransition<InvoiceDetails>(
              key: ObjectKey(_invoiceDetails),
              slowAction: () => _invoiceDetails,
              errorBuilder: (_, _) => _buildLoadError(),
              builder: _buildInvoice,
            ),
    ),
  );

  Widget _buildInvoice(BuildContext context, InvoiceDetails? details) {
    if (details == null) {
      return const SizedBox.shrink();
    }
    final invoice = details.invoice;
    final job = details.job;
    final customer = details.customer;
    final lineGroups = details.lineGroups;
    final readOnlyInvoice = invoice.isExternallyDeletedOrVoided;
    final actions = InvoiceEditorActions(details);
    final canChangeInvoice = actions.canEdit;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Surface(
            elevation: SurfaceElevation.e6,
            child: HMBFormSection(
              spacing: HMBSpacing.kSectionGap,
              children: [
                HMBColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Created ${formatDate(invoice.createdDate)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text('Customer: ${customer?.name ?? "N/A"}'),
                    Text('Job: ${job.summary} #${job.id}'),
                  ],
                ),
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
                    if (invoice.externalSyncStatus !=
                        InvoiceExternalSyncStatus.none)
                      Text(
                        'Accounting: '
                        '${_syncStatusLabel(invoice.externalSyncStatus)}',
                      ),
                  ],
                ),
                _buildLedgerSummary(details),
                if (!readOnlyInvoice) ...[
                  _section('Delivery', [
                    if (_accountingError != null) Text(_accountingError!),
                    if (_accountingUnavailable)
                      HMBButtonSecondary(
                        label: 'Retry accounting settings',
                        hint: 'Reload the accounting connection',
                        onPressed: _reloadInvoiceAndRefresh,
                      ),
                    Wrap(
                      spacing: HMBSpacing.kRelated,
                      runSpacing: HMBSpacing.kCompact,
                      children: [
                        BuildSendButton(
                          context: context,
                          mounted: mounted,
                          invoice: invoice,
                          onReturned: _reloadInvoiceAndRefresh,
                        ),
                        if (!invoice.isUploaded())
                          HMBButtonSecondary(
                            label: _accounting.hasSnapshotAttempt
                                ? 'Review accounting export'
                                : 'Upload',
                            hint: _accounting.explanation,
                            onPressed:
                                !_accountingUnavailable &&
                                    _accounting.canSend &&
                                    !(_accounting.destination ==
                                            InvoiceAccountingDestination
                                                .synced &&
                                        invoice.isManagedLocally) &&
                                    !_sendingToAccounting
                                ? _sendToAccounting
                                : null,
                          ),
                      ],
                    ),
                    if (!invoice.isUploaded() && !_accountingUnavailable)
                      Text(
                        _accounting.destination ==
                                    InvoiceAccountingDestination.synced &&
                                invoice.isManagedLocally
                            ? 'Upload is unavailable for invoices with manual '
                                  'payment tracking.'
                            : _accounting.explanation,
                      ),
                  ]),
                  if (actions.hasPaymentActions)
                    _section('Manage payments', [
                      if (invoice.paymentSource == InvoicePaymentSource.unknown)
                        const Text(
                          'Payment tracking needs review. Convert to '
                          'manual tracking only if this invoice is '
                          'no longer '
                          'managed by your accounting software.',
                        ),
                      if (actions.canAllocate || actions.canConvertTracking)
                        Wrap(
                          spacing: HMBSpacing.kRelated,
                          runSpacing: HMBSpacing.kCompact,
                          children: [
                            if (_canApplyPayment(details))
                              HMBButtonSecondary(
                                label: 'Record or allocate payment',
                                hint:
                                    'Record a new payment or allocate '
                                    'an existing payment',
                                onPressed: () => _applyPayment(details),
                              ),
                            if (invoice.canConvertToManualTracking)
                              HMBButtonSecondary(
                                label: 'Convert to Manual Tracking',
                                hint:
                                    'Switch this invoice to manual payment '
                                    'tracking',
                                onPressed: () async {
                                  await _convertToManualTracking();
                                },
                              ),
                          ],
                        ),
                      if (actions.hasMoreActions)
                        Material(
                          type: MaterialType.transparency,
                          child: ExpansionTile(
                            title: const Text('More invoice actions'),
                            tilePadding: EdgeInsets.zero,
                            children: [
                              Wrap(
                                spacing: HMBSpacing.kRelated,
                                runSpacing: HMBSpacing.kCompact,
                                children: [
                                  if (_canRecordAdjustment(details))
                                    HMBButtonSecondary(
                                      label: 'Add Adjustment',
                                      hint:
                                          'Record an adjustment '
                                          'against this invoice',
                                      onPressed: () async {
                                        await _recordAdjustment(details);
                                      },
                                    ),
                                  if (_canWriteOffSmallBalance(details))
                                    HMBButtonSecondary(
                                      label: 'Write Off Small Balance',
                                      hint:
                                          'Write off a small '
                                          'unpaid invoice balance',
                                      onPressed: () async {
                                        await _writeOffBalance(
                                          details,
                                          smallBalance: true,
                                        );
                                      },
                                    ),
                                  if (_canWriteOffBalance(details) &&
                                      !_canWriteOffSmallBalance(details))
                                    HMBButtonSecondary(
                                      label: 'Write Off',
                                      hint:
                                          'Write off this unpaid '
                                          'invoice balance',
                                      onPressed: () async {
                                        await _writeOffBalance(details);
                                      },
                                    ),
                                  if (_canVoidInvoice(details))
                                    HMBButtonSecondary(
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
                                ],
                              ),
                            ],
                          ),
                        ),
                    ]),
                ],
                _section('Invoice items', [
                  if (canChangeInvoice)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: HMBButtonSecondary(
                        label: 'Add Discount',
                        hint: 'Add a discount line to this invoice',
                        onPressed: _promptAddDiscount,
                      ),
                    ),
                  // Show all line groups and lines inline
                  for (final group in lineGroups) ...[
                    Text(
                      group.group.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final line in group.lines) ...[
                      Surface(
                        child: HMBFormSection(
                          children: [
                            Text(
                              line.description,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Quantity: ${line.quantity} · '
                              'Unit price: ${line.unitPrice}',
                            ),
                            Text('Total: ${line.lineTotal}'),
                            Text('Status: ${line.status.description}'),
                            if (canChangeInvoice)
                              Wrap(
                                spacing: HMBSpacing.kRelated,
                                children: [
                                  HMBEditIcon(
                                    onPressed: () =>
                                        _editInvoiceLine(context, line),
                                    hint: 'Edit Invoice Line',
                                  ),
                                  HMBDeleteIcon(
                                    onPressed: () => _deleteInvoiceLine(line),
                                    hint: 'Delete Invoice Line',
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => HMBFormSection(
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      ...children,
    ],
  );

  String _syncStatusLabel(InvoiceExternalSyncStatus status) => switch (status) {
    InvoiceExternalSyncStatus.none => 'Not synced',
    InvoiceExternalSyncStatus.linked => 'Linked to accounting',
    InvoiceExternalSyncStatus.deleted => 'Deleted in accounting',
    InvoiceExternalSyncStatus.voided => 'Voided in accounting',
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

    return Surface(
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
            Text(
              details.invoice.isExternallyDeletedOrVoided
                  ? 'No email address recorded.'
                  : 'Add a billing email before sending this invoice.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                HMBButtonSecondary(
                  label: 'Change Contact',
                  hint: 'Select the billing contact for this invoice',
                  onPressed: () => _changeBillingContact(details),
                ),
                if (contact != null)
                  HMBButtonSecondary(
                    label: 'Edit Contact',
                    hint: 'Edit ${contact.fullname.trim()}',
                    onPressed: () => _editBillingContact(details, contact),
                  ),
                if (jobContact != null &&
                    (hasMismatch ||
                        resolved.source ==
                            InvoiceBillingContactSource.jobFallback))
                  HMBButtonSecondary(
                    label: 'Use Job Contact',
                    hint: 'Use ${jobContact.fullname.trim()} for this invoice',
                    onPressed: () =>
                        _saveBillingContact(details.invoice, jobContact),
                  ),
              ],
            ),
        ],
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
      InvoicePaymentSource.xero => 'Managed by accounting',
      InvoicePaymentSource.unknown => 'Needs review',
    };
  }

  Widget _buildLedgerSummary(InvoiceDetails details) {
    final ledger = details.ledger;
    return Surface(
      elevation: SurfaceElevation.e1,
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoice summary',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text('Invoice total: ${ledger.total}'),
              if (InvoiceEditorActions(details).financiallyActive)
                Text('Paid: ${ledger.paid}'),
              if (ledger.credited.isNonZero)
                Text('Credited: ${ledger.credited}'),
              if (ledger.adjusted.isNonZero)
                Text('Adjusted: ${ledger.adjusted}'),
              if (InvoiceEditorActions(details).financiallyActive)
                Text('Balance: ${ledger.balance}'),
              Text('Status: ${_ledgerStatusLabel(ledger.status)}'),
            ],
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
                    Expanded(child: Text(_ledgerHistoryLabel(entry))),
                  ],
                ),
              ),
          ],
        ],
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

  bool _canApplyPayment(InvoiceDetails details) =>
      InvoiceEditorActions(details).canAllocate;

  bool _canRecordAdjustment(InvoiceDetails details) =>
      InvoiceEditorActions(details).canAdjust;

  bool _canWriteOffSmallBalance(InvoiceDetails details) =>
      _canWriteOffBalance(details) &&
      details.ledger.balance <= MoneyEx.fromInt(100);

  bool _canWriteOffBalance(InvoiceDetails details) =>
      InvoiceEditorActions(details).canWriteOff;

  bool _canVoidInvoice(InvoiceDetails details) =>
      InvoiceEditorActions(details).canVoid;

  Future<void> _convertToManualTracking() async {
    await DaoInvoice().convertToManualTracking(invoiceId);
    await _reloadInvoice();
    if (!mounted) {
      return;
    }
    HMBToast.info('Invoice converted to manual tracking');
    setState(() {});
  }

  Future<void> _applyPayment(InvoiceDetails details) async {
    final customerId = details.billingCustomer?.id;
    if (customerId == null) {
      HMBToast.error(
        'Set the job’s billing customer before recording '
        'or allocating a payment.',
      );
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

  bool get _canContinueAccounting =>
      mounted && (ModalRoute.of(context)?.isCurrent ?? false);

  Future<void> _sendToAccounting() async {
    if (_sendingToAccounting) {
      return;
    }
    setState(() {
      _sendingToAccounting = true;
      _accountingError = null;
    });
    try {
      final state = await BlockingUI().runAndWait(
        () => (widget.loadAccounting ?? InvoiceAccountingState.load)(invoiceId),
        label: 'Checking accounting connection',
      );
      if (!mounted) {
        return;
      }
      if (!_canContinueAccounting) {
        return;
      }
      setState(() => _accounting = state);
      if (!state.canSend) {
        return;
      }
      final details = await _invoiceDetails;
      if (!mounted ||
          !_canContinueAccounting ||
          details.invoice.isUploaded() ||
          details.invoice.isExternallyDeletedOrVoided ||
          (state.destination == InvoiceAccountingDestination.synced &&
              details.invoice.isManagedLocally)) {
        return;
      }
      if (state.destination == InvoiceAccountingDestination.snapshot) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => QuickBooksExportScreen(invoice: details.invoice),
          ),
        );
      } else {
        await _uploadInvoiceToAccounting();
      }
      if (mounted) {
        await _reloadInvoiceAndRefresh();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _accountingError =
              'Could not complete the accounting action. '
              'Review the connection and invoice status before retrying.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sendingToAccounting = false);
      }
    }
  }

  Future<void> _uploadInvoiceToAccounting() async {
    try {
      final details = await _invoiceDetails;
      if (!_canContinueAccounting) {
        return;
      }
      final invoice = details.invoice;
      if (invoice.isUploaded()) {
        HMBToast.error('This invoice has already been sent to accounting.');
        return;
      }
      try {
        await (widget.prepareAccountingContact ??
            _prepareBillingContactForDelivery)(invoice);
      } on InvoiceException catch (error) {
        await _showBillingContactProblem(details, error.message);
        return;
      }

      if (!_canContinueAccounting) {
        return;
      }
      await BlockingUI().runAndWait(() async {
        await (widget.accountingLogin ?? AccountingAdaptor.get().login)();
        if (!_canContinueAccounting) {
          return;
        }
        await (widget.accountingUpload ??
            AccountingAdaptor.get().uploadInvoice)(invoice);
      }, label: 'Sending invoice to accounting');
      if (!_canContinueAccounting) {
        return;
      }
      HMBToast.info('Invoice sent to accounting successfully');
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
      if (!_canContinueAccounting) {
        return;
      }
      HMBToast.error(
        'Failed to upload invoice: $e',
        acknowledgmentRequired: true,
      );
    }
  }

  Future<void> _prepareBillingContactForDelivery(Invoice invoice) async {
    final resolved = await resolveInvoiceBillingContact(invoice);
    if (!_canContinueAccounting) {
      return;
    }
    final contact = await requireInvoiceBillingContact(invoice);
    if (!_canContinueAccounting) {
      return;
    }
    if (resolved.source == InvoiceBillingContactSource.jobFallback &&
        invoice.canChangeBillingContact) {
      await DaoInvoice().updateBillingContact(invoice.id, contact.id);
      invoice.billingContactId = contact.id;
    }
  }

  Future<void> _showBillingContactProblem(
    InvoiceDetails details,
    String message,
  ) async {
    if (!_canContinueAccounting) {
      return;
    }
    final contact = details.billingContact.contact;
    final action = await showDialog<_BillingContactFix>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Billing contact needs attention'),
        content: Text(message),
        actions: [
          HMBCancelButton(
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
    if (!_canContinueAccounting) {
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
    final details = await _invoiceDetails;
    if (!InvoiceEditorActions(details).canEdit) {
      HMBToast.error('Only drafts without ledger activity can be edited.');
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
    final details = await _invoiceDetails;
    if (!InvoiceEditorActions(details).canEdit) {
      HMBToast.error('Only drafts without ledger activity can be edited.');
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
    if (!InvoiceEditorActions(details).canEdit) {
      HMBToast.error('Only drafts without ledger activity can be changed.');
      return;
    }

    if (!mounted) {
      return;
    }
    final request = await showDialog<InvoiceDiscountRequest>(
      context: context,
      builder: (_) => const InvoiceDiscountDialog(),
    );
    if (request == null || !mounted) {
      return;
    }

    try {
      await DaoInvoice().addDiscountLine(
        invoice: details.invoice,
        amount: request.amount,
        description: request.description,
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

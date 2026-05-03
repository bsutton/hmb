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

import 'package:flutter/material.dart' hide StatefulBuilder;
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart' show Strings;

import '../../api/external_accounting.dart';
import '../../api/xero/xero.g.dart';
import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/dart/money_ex.dart';
import '../../util/flutter/app_title.dart';
import '../crud/base_full_screen/base_full_screen.g.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/select/hmb_select_job.dart';
import '../widgets/widgets.g.dart';
import 'create_invoice_ui.dart';
import 'dialog_select_tasks.dart';
import 'edit_invoice_screen.dart';
import 'invoice_details.dart';
import 'list_invoice_card.dart';
import 'select_job_dialog.dart';
import 'void_invoice_dialog.dart';

class InvoiceListScreen extends StatefulWidget {
  // The list of invoice are restricted to this job if passed.
  final Job? jobRestriction;

  const InvoiceListScreen({super.key, this.jobRestriction});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  // late List<Invoice> _invoices;
  final selectedJob = SelectedJob();
  Customer? selectedCustomer;
  String? filterText;
  var showOldJobs = false;
  var showPaidInvoices = true;
  var showOlderPaidInvoices = false;
  var showDeletedOrVoidedInvoices = false;

  bool get _isJobRestricted => widget.jobRestriction != null;

  DateTime get _recentlyPaidCutoff =>
      DateTime.now().subtract(const Duration(days: 30));

  bool get _hasScopedInvoiceFilter =>
      _isJobRestricted ||
      selectedJob.jobId != null ||
      selectedCustomer != null ||
      Strings.isNotBlank(filterText);

  @override
  void initState() {
    super.initState();
    setAppTitle('Invoices');
    selectedJob.jobId = widget.jobRestriction?.id;
  }

  @override
  Widget build(BuildContext context) => EntityListScreen<Invoice>(
    listCardTitle: (inv) => Text('Invoice #${inv.id}'),
    entityNameSingular: 'Invoice',
    entityNamePlural: 'Invoices',
    dao: DaoInvoice(),
    fetchList: _fetchFilteredInvoices,
    onAdd: _createInvoice,
    onEdit: (invoice) => FutureBuilderEx(
      future: InvoiceDetails.load(invoice!.id),
      builder: (context, invoiceDetails) =>
          InvoiceEditScreen(invoiceDetails: invoiceDetails!),
    ),
    onDelete: _deleteInvoice,
    cardHeight: 340,
    background: (_) async => Colors.transparent,
    listCard: _buildInvoiceCard,
    filterSheetBuilder: _buildFilterSheet,
    isFilterActive: () =>
        (!_isJobRestricted && selectedJob.jobId != null) ||
        (!_isJobRestricted && selectedCustomer != null) ||
        showOldJobs ||
        !showPaidInvoices ||
        (!_isJobRestricted && showOlderPaidInvoices) ||
        showDeletedOrVoidedInvoices ||
        Strings.isNotBlank(filterText),
    onFilterReset: () {
      selectedJob.jobId = widget.jobRestriction?.id;
      selectedCustomer = null;
      filterText = null;
      showOldJobs = false;
      showPaidInvoices = true;
      showOlderPaidInvoices = false;
      showDeletedOrVoidedInvoices = false;
    },
  );

  Future<List<Invoice>> _fetchFilteredInvoices(String? filter) async {
    filterText = filter;
    var invoices = await DaoInvoice().getByFilter(
      filterText,
      includePaid: showPaidInvoices,
      paidSince:
          !showOlderPaidInvoices && showPaidInvoices && !_hasScopedInvoiceFilter
          ? _recentlyPaidCutoff
          : null,
      includeDeletedOrVoided: showDeletedOrVoidedInvoices,
    );
    final restrictedJobId = widget.jobRestriction?.id ?? selectedJob.jobId;
    if (restrictedJobId != null) {
      invoices = invoices.where((i) => i.jobId == restrictedJobId).toList();
    }
    if (!_isJobRestricted && selectedCustomer != null) {
      final filtered = <Invoice>[];
      for (final invoice in invoices) {
        final job = await DaoJob().getById(invoice.jobId);
        if (job?.customerId == selectedCustomer!.id) {
          filtered.add(invoice);
        }
      }
      invoices = filtered;
    }
    final details = <Invoice>[];
    for (final invoice in invoices) {
      details.add(invoice);
    }
    return details;
  }

  Future<Invoice?> _createInvoice() async {
    final job = widget.jobRestriction ?? await SelectJobDialog.show(context);

    if (job == null) {
      return null;
    }

    if (job.hourlyRate == MoneyEx.zero) {
      HMBToast.error("Hourly rate must be set for job '${job.summary}'");
      return null;
    }

    if ((await DaoTimeEntry().getActiveEntry()) != null) {
      HMBToast.error('Cannot create an invoice while a Task timer is active');
      return null;
    }

    if (!mounted) {
      return null;
    }

    if (job.billingType == BillingType.fixedPrice) {
      await openMilestonesForFixedPriceJob(job: job, context: context);
      return null;
    }

    try {
      final invoiceOptions = await selectTasksToInvoice(
        context: context,
        job: job,
        title: 'Tasks to bill',
      );

      if (invoiceOptions == null) {
        return null;
      }
      if (invoiceOptions.selectedTaskIds.isNotEmpty ||
          invoiceOptions.billBookingFee) {
        return await createTimeAndMaterialsInvoice(
          job,
          invoiceOptions.contact,
          invoiceOptions.selectedTaskIds,
          groupByTask: invoiceOptions.groupByTask,
          billBookingFee: invoiceOptions.billBookingFee,
        );
      } else {
        HMBToast.info(
          'You must select at least one Task or the Booking Fee to invoice',
        );
      }
    } catch (e) {
      HMBToast.error(
        'Failed to create invoice: $e',
        acknowledgmentRequired: true,
      );
    }
    return null;
  }

  Widget _buildFilterSheet(void Function() onChange) => Padding(
    padding: const EdgeInsets.all(8),
    child: HMBColumn(
      children: [
        if (!_isJobRestricted)
          HMBSelectJob(
            title: 'Filter By Job',
            selectedJob: selectedJob,
            items: (filter) => showOldJobs
                ? DaoJob().getByFilter(filter)
                : DaoJob().getActiveJobs(filter),
            onSelected: (job) => setState(() {
              selectedJob.jobId = job?.id;
              onChange();
            }),
          ),
        if (!_isJobRestricted)
          CheckboxListTile(
            title: const Text('Show old jobs'),
            value: showOldJobs,
            onChanged: (value) => setState(() {
              showOldJobs = value ?? false;
              onChange();
            }),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        CheckboxListTile(
          title: const Text('Show paid invoices'),
          value: showPaidInvoices,
          onChanged: (value) => setState(() {
            showPaidInvoices = value ?? false;
            if (!showPaidInvoices) {
              showOlderPaidInvoices = false;
            }
            onChange();
          }),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (!_isJobRestricted)
          CheckboxListTile(
            title: const Text('Show older paid invoices'),
            subtitle: const Text(
              'Default view shows outstanding invoices and invoices '
              'paid in the last 30 days.',
            ),
            value: showOlderPaidInvoices,
            onChanged: showPaidInvoices
                ? (value) => setState(() {
                    showOlderPaidInvoices = value ?? false;
                    onChange();
                  })
                : null,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        CheckboxListTile(
          title: const Text('Show deleted and voided invoices'),
          value: showDeletedOrVoidedInvoices,
          onChanged: (value) => setState(() {
            showDeletedOrVoidedInvoices = value ?? false;
            onChange();
          }),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (!_isJobRestricted)
          HMBDroplist<Customer>(
            title: 'Filter by Customer',
            items: (filter) => DaoCustomer().getByFilter(filter),
            format: (customer) => customer.name,
            required: false,
            selectedItem: () async => selectedCustomer,
            onChanged: (customer) {
              selectedCustomer = customer;
              onChange();
            },
          ),
      ],
    ),
  );

  Widget _buildInvoiceCard(Invoice invoice) => FutureBuilderEx(
    future: InvoiceDetails.load(invoice.id),
    builder: (context, invoiceDetails) => InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              InvoiceEditScreen(invoiceDetails: invoiceDetails),
        ),
      ),
      child: ListInvoiceCard(
        invoiceDetails: invoiceDetails!,
        showJobDetails: widget.jobRestriction == null,
      ),
    ),
  );

  Future<bool> _deleteInvoice(Invoice invoice) async {
    try {
      final invoiceDetails = await InvoiceDetails.load(invoice.id);
      final sent = invoiceDetails.invoice.sent;
      if (sent) {
        if (!mounted) {
          return false;
        }
        return promptAndVoidInvoice(
          context: context,
          invoice: invoiceDetails.invoice,
        );
      }

      if (await ExternalAccounting().isEnabled()) {
        if (Strings.isNotBlank(invoiceDetails.invoice.invoiceNum)) {
          final xeroApi = XeroApi();
          await xeroApi.login();
          await BlockingUI().runAndWait(() async {
            await xeroApi.deleteInvoice(invoiceDetails.invoice);
          }, label: 'Deleting Invoice');
        }
      }
      await DaoInvoice().delete(invoiceDetails.invoice.id);
      HMBToast.info('Invoice ${invoiceDetails.invoice.bestNumber} deleted');
      return true;
    } catch (e) {
      HMBToast.error('Failed to delete invoice: $e');
    }
    return false;
  }
}

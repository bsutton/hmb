/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart' hide StatefulBuilder;
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart' show Strings;

import '../../../util/format.dart';
import '../../api/external_accounting.dart';
import '../../api/xero/xero.g.dart';
import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/app_title.dart';
import '../../util/money_ex.dart';
import '../crud/base_full_screen/base_full_screen.g.dart';
import '../crud/job/edit_job_screen.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/select/hmb_select_job.dart';
import '../widgets/widgets.g.dart';
import 'dialog_select_tasks.dart';
import 'edit_invoice_screen.dart';
import 'invoice_details.dart';
import 'select_job_dialog.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key, this.job});

  final Job? job;

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  // late List<Invoice> _invoices;
  final selectedJob = SelectedJob();
  Customer? selectedCustomer;
  String? filterText;

  @override
  void initState() {
    super.initState();
    setAppTitle('Invoices');
    selectedJob.jobId = widget.job?.id;
  }

  @override
  Widget build(BuildContext context) => EntityListScreen<Invoice>(
    title: (inv) => Text('Invoice #${inv.id}'),
    // key: ValueKey<String?>(
    //   '$filterText:${selectedJob?.id}:${selectedCustomer?.id}',
    // ),
    pageTitle: 'Invoices',
    dao: DaoInvoice(),
    fetchList: (_) async => _fetchFilteredInvoices(),
    onAdd: () async => _createInvoice(),
    onEdit: (invoice) => FutureBuilderEx(
      future: InvoiceDetails.load(invoice!.id),
      builder: (context, invoiceDetails) =>
          InvoiceEditScreen(invoiceDetails: invoiceDetails!),
    ),
    onDelete: (entity) async => _deleteInvoice(entity),
    cardHeight: 250,
    background: (_) async => Colors.transparent,
    details: _buildInvoiceCard,
    filterSheetBuilder: widget.job == null ? _buildFilterSheet : null,
    isFilterActive: () =>
        selectedJob.jobId != null ||
        selectedCustomer != null ||
        Strings.isNotBlank(filterText),
    onFilterReset: () async {
      selectedJob.jobId = null;
      selectedCustomer = null;
      filterText = null;
    },
  );

  Future<List<Invoice>> _fetchFilteredInvoices() async {
    var invoices = await DaoInvoice().getByFilter(filterText);
    if (selectedJob.jobId != null) {
      invoices = invoices.where((i) => i.jobId == selectedJob.jobId).toList();
    }
    if (selectedCustomer != null) {
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
    final job = widget.job ?? await SelectJobDialog.show(context);

    if (job == null) {
      return null;
    }

    if (job.hourlyRate == MoneyEx.zero) {
      HMBToast.error('Hourly rate must be set for job ${job.summary}');
      return null;
    }

    if ((await DaoTimeEntry().getActiveEntry()) != null) {
      HMBToast.error('Cannot create an invoice while a Task timer is active');
      return null;
    }

    if (!mounted) {
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
    child: Column(
      children: [
        HMBSelectJob(
          title: 'Filter By Job',
          selectedJobId: selectedJob,
          onSelected: (job) => setState(() {
            selectedJob.jobId = job?.id;
            onChange();
          }),
        ),

        const SizedBox(height: 8),
        HMBDroplist<Customer>(
          // key: ValueKey(selectedCustomer),
          title: 'Filter by Customer',
          items: (filter) => DaoCustomer().getByFilter(filter),
          format: (customer) => customer.name,
          required: false,
          selectedItem: () async => selectedCustomer,
          onChanged: (customer) async {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Issued: ${formatDate(invoiceDetails!.invoice.createdDate)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Customer: ${invoiceDetails.customer?.name ?? 'N/A'}'),

          if (widget.job == null)
            HMBLinkInternal(
              label:
                  'Job: #${invoiceDetails.job.id} - ${invoiceDetails.job.summary} ',
              navigateTo: () async => JobEditScreen(job: invoiceDetails.job),
            ),
          Text(
            'Xero: ${invoiceDetails.invoice.invoiceNum == null ? 'Not uploaded' : '#${invoiceDetails.invoice.invoiceNum}'}',
          ),
          Text('Total: ${invoiceDetails.invoice.totalAmount}'),
          if (invoiceDetails.invoice.sent)
            const Text(
              'Sent',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    ),
  );

  Future<bool> _deleteInvoice(Invoice invoice) async {
    try {
      final invoiceDetails = await InvoiceDetails.load(invoice.id);
      final sent = invoiceDetails.invoice.sent;
      if (sent) {
        HMBToast.error(
          'This invoice has been sent to the customer and cannot be deleted',
        );
        return false;
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

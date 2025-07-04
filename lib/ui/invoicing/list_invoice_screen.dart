/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_customer.dart';
import '../../dao/dao_invoice.dart';
import '../../dao/dao_invoice_time_and_materials.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_time_entry.dart';
import '../../entity/customer.dart';
import '../../entity/invoice.dart';
import '../../entity/job.dart';
import '../../util/app_title.dart';
import '../../util/format.dart';
import '../../util/money_ex.dart';
import '../crud/job/job.g.dart';
import '../widgets/hmb_link_internal.dart';
import '../widgets/hmb_search.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/select/hmb_droplist.dart';
import 'dialog_select_tasks.dart';
import 'edit_invoice_screen.dart';
import 'invoice_details.dart';
import 'select_job_dialog.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  _InvoiceListScreenState createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends DeferredState<InvoiceListScreen> {
  late Future<List<InvoiceDetails>> _invoices;

  Job? selectedJob;
  Customer? selectedCustomer;
  String? filterText;
  final _filterController = TextEditingController();

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Invoices');
    await _refreshInvoiceList();
  }

  Future<void> _refreshInvoiceList() async {
    setState(() {
      _invoices = _fetchFilteredInvoices();
    });
  }

  Future<List<InvoiceDetails>> _fetchFilteredInvoices() async {
    var invoices = await DaoInvoice().getByFilter(filterText);

    if (selectedJob != null) {
      invoices = invoices.where((i) => i.jobId == selectedJob!.id).toList();
    }

    if (selectedCustomer != null) {
      invoices = await Future.wait(
        invoices.map((i) async {
          final job = await DaoJob().getById(i.jobId);
          return job?.customerId == selectedCustomer!.id ? i : null;
        }),
      ).then((list) => list.whereType<Invoice>().toList());
    }

    final invoiceDetails = <InvoiceDetails>[];
    for (final invoice in invoices) {
      invoiceDetails.add(await InvoiceDetails.load(invoice.id));
    }
    return invoiceDetails;
  }

  Future<void> _createInvoice() async {
    final job = await SelectJobDialog.show(context);

    if (job == null) {
      return;
    }

    if (job.hourlyRate == MoneyEx.zero) {
      HMBToast.error('Hourly rate must be set for job ${job.summary}');
      return;
    }

    if ((await DaoTimeEntry().getActiveEntry()) != null) {
      HMBToast.error('Cannot create an invoice while a Task timer is active');
      return;
    }

    if (mounted) {
      final invoiceOptions = await selectTasksToInvoice(
        context: context,
        job: job,
        title: 'Tasks to bill',
      );

      if (invoiceOptions != null) {
        try {
          if (invoiceOptions.selectedTaskIds.isNotEmpty ||
              invoiceOptions.billBookingFee) {
            await createTimeAndMaterialsInvoice(
              job,
              invoiceOptions.contact,
              invoiceOptions.selectedTaskIds,
              groupByTask: invoiceOptions.groupByTask,
              billBookingFee: invoiceOptions.billBookingFee,
            );

            await _refreshInvoiceList();
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

        await _refreshInvoiceList();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 80,
      title: HMBSearchWithAdd(
        onSearch: (filter) async {
          filterText = filter;
          await _refreshInvoiceList();
        },
        onAdd: _createInvoice,
      ),
      automaticallyImplyLeading: false,
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              HMBDroplist<Job>(
                title: 'Filter by Job',
                // ignore: discarded_futures
                items: (filter) => DaoJob().getActiveJobs(filter),
                format: (job) => job.summary,
                required: false,
                selectedItem: () async => selectedJob,
                onChanged: (job) async {
                  setState(() {
                    selectedJob = job;
                  });
                  await _refreshInvoiceList();
                },
              ),
              const SizedBox(height: 8),
              HMBDroplist<Customer>(
                title: 'Filter by Customer',
                // ignore: discarded_futures
                items: (filter) => DaoCustomer().getByFilter(filter),
                format: (customer) => customer.name,
                required: false,
                selectedItem: () async => selectedCustomer,
                onChanged: (customer) async {
                  setState(() {
                    selectedCustomer = customer;
                  });
                  await _refreshInvoiceList();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilderEx<List<InvoiceDetails>>(
            future: _invoices,
            builder: (context, invoices) {
              if (invoices == null || invoices.isEmpty) {
                return const Center(child: Text('No invoices found.'));
              } else {
                return ListView.builder(
                  itemCount: invoices.length,
                  itemBuilder: (context, index) {
                    final details = invoices[index];
                    return InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) =>
                                InvoiceEditScreen(invoiceDetails: details),
                          ),
                        );
                        await _refreshInvoiceList();
                      },
                      child: Card(
                        margin: const EdgeInsets.all(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invoice #${details.invoice.id} Issued: ${formatDate(details.invoice.createdDate)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Customer: ${details.customer?.name ?? "N/A"}',
                              ),
                              HMBLinkInternal(
                                label:
                                    'Job: #${details.job.id} - ${details.job.summary} ',
                                navigateTo: () async =>
                                    JobEditScreen(job: details.job),
                              ),
                              Text(
                                'Xero: ${details.invoice.invoiceNum == null ? 'Not uploaded' : '#${details.invoice.invoiceNum}'}',
                              ),
                              Text('Total: ${details.invoice.totalAmount}'),
                              // Display "Sent" if sent is true
                              if (details.invoice.sent)
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
                      ),
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }
}

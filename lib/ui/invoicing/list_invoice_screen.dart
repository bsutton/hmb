import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:strings/strings.dart';

import '../../api/xero/xero_api.dart';
import '../../dao/dao_contact.dart';
import '../../dao/dao_customer.dart';
import '../../dao/dao_invoice.dart';
import '../../dao/dao_invoice_line.dart';
import '../../dao/dao_invoice_line_group.dart';
import '../../dao/dao_invoice_time_and_materials.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_task_item.dart';
import '../../dao/dao_time_entry.dart';
import '../../entity/customer.dart';
import '../../entity/invoice.dart';
import '../../entity/invoice_line.dart';
import '../../entity/job.dart';
import '../../util/money_ex.dart';
import '../dialog/hmb_are_you_sure_dialog.dart';
import '../widgets/fields/hmb_text_field.dart';
import '../widgets/hmb_add_button.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/select/hmb_droplist.dart';
import 'dialog_select_tasks.dart';
import 'edit_invoice_line_dialog.dart';
import 'invoice_card.dart';
import 'select_job_dialog.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  _InvoiceListScreenState createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  late Future<List<Invoice>> _invoices;
  final XeroApi _xeroApi = XeroApi();

  Job? selectedJob;
  Customer? selectedCustomer;
  String? filterText;
  final TextEditingController _filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshInvoiceList();
  }

  Future<void> _refreshInvoiceList() async {
    setState(() {
      _invoices = _fetchFilteredInvoices();
    });
  }

  // Future<bool> hasBillableItems() async {
  //   final hasBillableTasks = await DaoJob().hasBillableTasks(job);
  //   final hasBillableBookingFee = await DaoJob().hasBillableBookingFee(job);

  //   return Future.value(hasBillableTasks || hasBillableBookingFee);
  // }

  Future<List<Invoice>> _fetchFilteredInvoices() async {
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

    return invoices;
  }

  Future<void> _createInvoice() async {
    final job = await showDialog<Job?>(
      context: context,
      builder: (context) => const SelectJobDialog(),
    );

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
      final invoiceOptions = await showInvoice(context: context, job: job);

      if (invoiceOptions != null) {
        try {
          if (invoiceOptions.selectedTaskIds.isNotEmpty ||
              invoiceOptions.billBookingFee) {
            await createTimeAndMaterialsInvoice(
                job, invoiceOptions.selectedTaskIds,
                groupByTask: invoiceOptions.groupByTask,
                billBookingFee: invoiceOptions.billBookingFee);

            await _refreshInvoiceList();
          } else {
            HMBToast.info('''
You must select at least one Task or the Booking Fee to invoice''');
          }
          // ignore: avoid_catches_without_on_clauses
        } catch (e) {
          HMBToast.error('Failed to create invoice: $e',
              acknowledgmentRequired: true);
        }

        await _refreshInvoiceList();
      }
    }
  }

  Future<void> _deleteInvoice(Invoice invoice) async {
    await areYouSure(
      context: context,
      title: 'Delete Confirmation',
      message: 'Are you sure you want to delete this invoice?',
      onConfirmed: () async {
        try {
          final sent = invoice.sent;
          await DaoInvoice().delete(invoice.id);
          if (Strings.isNotBlank(invoice.invoiceNum)) {
            await _xeroApi.login();
            if (sent) {
              HMBToast.error(
                  'This invoice has been sent to the customer and cannot be deleted');
            } else {
              await _xeroApi.deleteInvoice(invoice);
            }
          }
          await _refreshInvoiceList();
          // ignore: avoid_catches_without_on_clauses
        } catch (e) {
          HMBToast.error('Failed to delete invoice: $e');
        }
      },
    );
  }

  Future<void> _uploadInvoiceToXero(Invoice invoice) async {
    try {
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
      await _refreshInvoiceList();
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

  Future<void> _editInvoiceLine(BuildContext context, InvoiceLine line) async {
    final editedLine = await showDialog<InvoiceLine>(
      context: context,
      builder: (context) => EditInvoiceLineDialog(line: line),
    );

    if (editedLine != null) {
      await DaoInvoiceLine().update(editedLine);
      await DaoInvoice().recalculateTotal(editedLine.invoiceId);
      await _refreshInvoiceList();
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
        // Mark source item as not billed
        await DaoTaskItem().markNotBilled(line.id);
        await DaoTimeEntry().markAsNotbilled(line.id);

        // Delete the invoice line
        await DaoInvoiceLine().delete(line.id);

        // Check if the line group is empty and delete if necessary
        final remainingLines = await DaoInvoiceLine()
            .getByInvoiceLineGroupId(line.invoiceLineGroupId);

        if (remainingLines.isEmpty) {
          await DaoInvoiceLineGroup().delete(line.invoiceLineGroupId);
        }

        // Recalculate the invoice total
        await DaoInvoice().recalculateTotal(line.invoiceId);

        await _refreshInvoiceList();
        // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        HMBToast.error('Failed to delete invoice line: $e',
            acknowledgmentRequired: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 80,
          title: const Text('Invoices'),
          automaticallyImplyLeading: false,
          actions: _buildCommands(),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  HMBDroplist<Job>(
                    title: 'Filter by Job',
                    items: (filter) async => DaoJob().getActiveJobs(filter),
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
                    items: (filter) async => DaoCustomer().getByFilter(filter),
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
              child: FutureBuilderEx<List<Invoice>>(
                future: _invoices,
                waitingBuilder: (_) =>
                    const Center(child: CircularProgressIndicator()),
                builder: (context, invoices) {
                  if (invoices == null || invoices.isEmpty) {
                    return const Center(
                      child: Text('No invoices found.'),
                    );
                  } else {
                    return _buildInvoiceList(invoices);
                  }
                },
              ),
            ),
          ],
        ),
      );

  Widget _buildInvoiceList(List<Invoice> invoices) => ListView.builder(
        itemCount: invoices.length,
        itemBuilder: (context, index) {
          final invoice = invoices[index];
          return InvoiceCard(
            invoice: invoice,
            onDeleteInvoice: () async => _deleteInvoice(invoice),
            onUploadInvoiceToXero: () async => _uploadInvoiceToXero(invoice),
            onEditInvoiceLine: _editInvoiceLine,
            onDeleteInvoiceLine: _deleteInvoiceLine,
          );
        },
      );

  List<Widget> _buildCommands() => [
        SizedBox(
          width: 250,
          height: 80,
          child: HMBTextField(
            leadingSpace: false,
            labelText: 'Filters',
            controller: _filterController,
            onChanged: (newValue) async {
              filterText = newValue;
              await _refreshInvoiceList();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () async {
            _filterController.clear();
            filterText = null;
            await _refreshInvoiceList();
          },
        ),
        HMBButtonAdd(
          enabled: true,
          onPressed: _createInvoice,
        ),
      ];

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }
}

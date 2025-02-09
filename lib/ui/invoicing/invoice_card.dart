import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../../dao/dao.g.dart';
import '../../entity/_index.g.dart';
import '../../util/format.dart';
import '../widgets/hmb_button.dart';
import 'build_send_button.dart';

class InvoiceCard extends StatefulWidget {
  const InvoiceCard({
    required this.invoice,
    required this.onDeleteInvoice,
    required this.onUploadInvoiceToXero,
    required this.onEditInvoiceLine,
    required this.onDeleteInvoiceLine,
    super.key,
  });

  final Invoice invoice;
  final VoidCallback onDeleteInvoice;
  final VoidCallback onUploadInvoiceToXero;
  final void Function(BuildContext, InvoiceLine) onEditInvoiceLine;
  final void Function(InvoiceLine) onDeleteInvoiceLine;

  @override
  _InvoiceCardState createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<InvoiceCard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.grey[200],
        child: ExpansionTile(
          title: _buildInvoiceTitle(widget.invoice),
          subtitle: Text('Total: ${widget.invoice.totalAmount}'),
          children: [
            FutureBuilderEx<List<InvoiceLineGroup>>(
              // ignore: discarded_futures
              future: DaoInvoiceLineGroup().getByInvoiceId(widget.invoice.id),
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
                  BuildSendButton(
                      context: context,
                      mounted: mounted,
                      invoice: widget.invoice),
                  if (Strings.isBlank(widget.invoice.invoiceNum))
                    HMBButton(
                      label: 'Upload to Xero',
                      onPressed: widget.onUploadInvoiceToXero,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
  Widget _buildInvoiceTitle(Invoice invoice) => FutureBuilderEx<JobAndCustomer>(
        // ignore: discarded_futures
        future: JobAndCustomer.fromInvoice(invoice),
        builder: (context, jobAndCustomer) {
          final jobName = jobAndCustomer!.job.summary;
          final customerName = jobAndCustomer.customer.name;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                // Prevents overflow
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice #${widget.invoice.id} Issued: ${formatDate(widget.invoice.createdDate)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Customer: $customerName'),
                    Text('Job: $jobName #${jobAndCustomer.job.id}'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: widget.onDeleteInvoice,
              ),
            ],
          );
        },
      );

  Widget _buildInvoiceGroup(List<InvoiceLineGroup> invoiceLineGroups) =>
      Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Column(
          children: invoiceLineGroups
              .map(
                (group) => ExpansionTile(
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

                        return _buildInvoiceLines(invoiceLines);
                      },
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      );

  Widget _buildInvoiceLines(List<InvoiceLine> invoiceLines) => Column(
        children: invoiceLines
            .map(
              (line) => ListTile(
                title: Text(line.description),
                subtitle: Text(
                  'Quantity: ${line.quantity}, Unit Price: ${line.unitPrice}, Status: ${line.status.toString().split('.').last}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total: ${line.lineTotal}'),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => widget.onDeleteInvoiceLine(line),
                    ),
                  ],
                ),
                onTap: () => widget.onEditInvoiceLine(context, line),
              ),
            )
            .toList(),
      );
}

class JobAndCustomer {
  JobAndCustomer({
    required this.job,
    required this.customer,
  });

  final Job job;
  final Customer customer;

  static Future<JobAndCustomer> fromInvoice(Invoice invoice) async {
    final job = (await DaoJob().getById(invoice.jobId))!;
    final customer = (await DaoCustomer().getById(job.customerId))!;
    return JobAndCustomer(job: job, customer: customer);
  }
}

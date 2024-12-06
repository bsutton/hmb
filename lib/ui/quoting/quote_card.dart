import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../../dao/_index.g.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../entity/quote.dart';
import '../../entity/quote_line.dart';
import '../../util/format.dart';
import '../crud/milestone_payment/edit_milestone_payment.dart';
import '../widgets/hmb_button.dart';
import '../widgets/media/pdf_preview.dart';
import 'edit_quote_line_dialog.dart';
import 'generate_quote_pdf.dart';
import 'job_quote.dart';

class QuoteCard extends StatefulWidget {
  const QuoteCard({
    required this.quote,
    required this.onDeleteQuote,
    required this.onEditQuote,
    super.key,
  });

  final Quote quote;
  final VoidCallback onDeleteQuote;
  final Future<void> Function(Quote) onEditQuote;

  @override
  _QuoteCardState createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard> {
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.grey[200],
        child: ExpansionTile(
          title: _buildQuoteTitle(widget.quote),
          subtitle: Text('Total: ${widget.quote.totalAmount}'),
          children: [
            FutureBuilderEx<JobQuote>(
              future: JobQuote.fromQuoteId(widget.quote.id),
              builder: (context, jobQuote) {
                if (jobQuote!.groups.isEmpty) {
                  return const ListTile(
                    title: Text('No quote lines found.'),
                  );
                }
                return _buildQuoteGroup(jobQuote);
              },
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  _buildGenerateButton(widget.quote),
                  _buildInvoiceButton(widget.quote),
                ],
              ),
            )
          ],
        ),
      );

  Widget _buildInvoiceButton(Quote quote) => HMBButton(
      label: 'Convert To Invoice',
      onPressed: () async {
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => EditMilestonesScreen(quoteId: quote.id),
            ),
          );
        }
      });

  Widget _buildQuoteTitle(Quote quote) => FutureBuilderEx<JobAndCustomer>(
        future: JobAndCustomer.fromQuote(quote),
        builder: (context, jobAndCustomer) {
          final jobName = jobAndCustomer!.job.summary;
          final customerName = jobAndCustomer.customer.name;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quote #${quote.id} Issued: ${formatDate(quote.createdDate)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Customer: $customerName'),
                    Text('Job: $jobName #${jobAndCustomer.job.id}'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: widget.onDeleteQuote,
              ),
            ],
          );
        },
      );

  Widget _buildQuoteGroup(JobQuote jobQuote) => Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Column(
          children: jobQuote.groups
              .map(
                (group) => ExpansionTile(
                  title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(group.group.name),
                        Text(group.total.toString())
                      ]),
                  children: [
                    if (group.lines.isEmpty)
                      const ListTile(
                        title: Text('No quote lines found.'),
                      )
                    else
                      _buildQuoteLines(group.lines),
                  ],
                ),
              )
              .toList(),
        ),
      );

  Widget _buildQuoteLines(List<QuoteLine> quoteLines) {
    final visibleLines = quoteLines;
    return Column(
      children: visibleLines
          .map(
            (line) => ListTile(
              title: Text(line.description),
              subtitle: Text(
                'Quantity: ${line.quantity}, Unit Price: ${line.unitPrice}, Status: ${line.status.toString().split('.').last}',
              ),
              trailing: Text('Total: ${line.lineTotal}'),
              onTap: () async => widget.onEditQuote(widget.quote),
            ),
          )
          .toList(),
    );
  }

  ElevatedButton _buildGenerateButton(Quote quote) => ElevatedButton(
        onPressed: () async {
          var displayCosts = true;
          var displayGroupHeaders = true;
          var displayItems = true;

          final result = await showDialog<Map<String, bool>>(
            context: context,
            builder: (context) {
              var tempDisplayCosts = displayCosts;
              var tempDisplayGroupHeaders = displayGroupHeaders;
              var tempDisplayItems = displayItems;

              return StatefulBuilder(
                builder: (context, setState) => AlertDialog(
                  title: const Text('Select Quote Options'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CheckboxListTile(
                        title: const Text('Display Costs'),
                        value: tempDisplayCosts,
                        onChanged: (value) {
                          setState(() {
                            tempDisplayCosts = value ?? true;
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Display Group Headers'),
                        value: tempDisplayGroupHeaders,
                        onChanged: (value) {
                          setState(() {
                            tempDisplayGroupHeaders = value ?? true;
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Display Items'),
                        value: tempDisplayItems,
                        onChanged: (value) {
                          setState(() {
                            tempDisplayItems = value ?? true;
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop({
                          'displayCosts': tempDisplayCosts,
                          'displayGroupHeaders': tempDisplayGroupHeaders,
                          'displayItems': tempDisplayItems,
                        });
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          );

          if (result != null && mounted) {
            displayCosts = result['displayCosts'] ?? true;
            displayGroupHeaders = result['displayGroupHeaders'] ?? true;
            displayItems = result['displayItems'] ?? true;

            final filePath = await generateQuotePdf(
              quote,
              displayCosts: displayCosts,
              displayGroupHeaders: displayGroupHeaders,
              displayItems: displayItems,
            );

            final system = await DaoSystem().get();
            final job = await DaoJob().getById(quote.jobId);
            final contacts = await DaoContact().getByJob(quote.jobId);
            final emailRecipients = contacts
                    .map((contact) => Strings.trim(contact.emailAddress))
                    .toList() ??
                [];
            if (mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => PdfPreviewScreen(
                    title: '''Quote #${quote.bestNumber} ${job!.summary}''',
                    filePath: filePath.path,
                    emailSubject: '${system!.businessName ?? 'Your'} quote',
                    emailBody: 'Please find the attached Quotation',
                    emailRecipients: emailRecipients,
                    onSent: () async {},
                  ),
                ),
              );
            }
          }
        },
        child: const Text('Preview PDF'),
      );

  Future<void> _editQuoteLine(BuildContext context, QuoteLine line) async {
    final editedLine = await showDialog<QuoteLine>(
      context: context,
      builder: (context) => EditQuoteLineDialog(line: line),
    );

    if (editedLine != null) {
      await DaoQuoteLine().update(editedLine);
      await DaoQuote().recalculateTotal(editedLine.quoteId);
      await widget.onEditQuote(widget.quote);
    }
  }
}

class JobAndCustomer {
  JobAndCustomer({
    required this.job,
    required this.customer,
  });

  final Job job;
  final Customer customer;

  static Future<JobAndCustomer> fromQuote(Quote quote) async {
    final job = (await DaoJob().getById(quote.jobId))!;
    final customer = (await DaoCustomer().getById(job.customerId))!;
    return JobAndCustomer(job: job, customer: customer);
  }
}

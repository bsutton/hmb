// ignore_for_file: avoid_catches_without_on_clauses

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../../dao/dao.g.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../entity/quote.dart';
import '../../entity/quote_line.dart';
import '../../util/format.dart';
import '../crud/milestone/edit_milestone_payment.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/layout/hmb_spacer.dart';
import '../widgets/media/pdf_preview.dart';
import '../widgets/surface.dart';
import '../widgets/text/hmb_text_themes.dart';
import 'quoting.g.dart';

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
  void initState() {
    quote = widget.quote;

    super.initState();
  }

  late Quote quote;

  @override
  Widget build(BuildContext context) => Surface(
        elevation: SurfaceElevation.e6,
        child: ExpansionTile(
          title: _buildQuoteTitle(quote),
          subtitle: Text('Total: ${quote.totalAmount}'),
          children: [
            FutureBuilderEx<JobQuote>(
                // ignore: discarded_futures
                future: JobQuote.fromQuoteId(quote.id),
                builder: (context, jobQuote) => Column(
                      children: [
                        // First row with Send, Milestones and Invoice buttons.
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              _buildSendButton(quote),
                              const SizedBox(width: 8),
                              _buildApprovedButton(quote),
                              const SizedBox(width: 8),
                              _buildRejectedButton(quote),
                            ],
                          ),
                        ),
                        // New row with Approved and Rejected buttons.
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              _buildMilestonesButton(quote),
                              const SizedBox(width: 8),
                              _buildCreateInvoiceButton(quote),
                            ],
                          ),
                        ),
                        if (jobQuote!.groups.isEmpty)
                          const ListTile(
                            title: Text('No quote lines found.'),
                          )
                        else
                          _buildQuoteGroup(jobQuote)
                      ],
                    )),
          ],
        ),
      );

  Widget _buildQuoteTitle(Quote quote) => FutureBuilderEx<JobAndCustomer>(
        // ignore: discarded_futures
        future: JobAndCustomer.fromQuote(quote),
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
                    HMBCardHeading(
                      'Quote #${quote.id} Issued: ${formatDate(quote.createdDate)}',
                    ),
                    Text('Customer: $customerName'),
                    Text('Job: $jobName #${jobAndCustomer.job.id}'),
                    // Optionally show current state:
                    Row(
                      children: [
                        Text('State: ${quote.state.name}'),
                        const HMBSpacer(width: true),
                        if (quote.state == QuoteState.sent)
                          Text(formatDate(quote.dateSent!)),
                        if (quote.state == QuoteState.approved)
                          Text(formatDate(quote.dateApproved!))
                      ],
                    ),
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
                        Expanded(child: HMBTextLine(group.group.name)),
                        HMBTextLine(group.total.toString())
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
                'Quantity: ${line.quantity}, Unit Price: ${line.unitPrice}, '
                'Status: ${line.status.toString().split('.').last}',
              ),
              trailing: Text('Total: ${line.lineTotal}'),
              onTap: () async => widget.onEditQuote(quote),
            ),
          )
          .toList(),
    );
  }

  HMBButton _buildSendButton(Quote quote) => HMBButton(
        label: 'Send...',
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
                    HMBButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    HMBButton(
                      label: 'OK',
                      onPressed: () {
                        Navigator.of(context).pop({
                          'displayCosts': tempDisplayCosts,
                          'displayGroupHeaders': tempDisplayGroupHeaders,
                          'displayItems': tempDisplayItems,
                        });
                      },
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
                .toList();
            if (mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => PdfPreviewScreen(
                    title: '''Quote #${quote.bestNumber} ${job!.summary}''',
                    filePath: filePath.path,
                    emailSubject: '${system.businessName ?? 'Your'} quote',
                    emailBody: 'Please find the attached Quotation',
                    emailRecipients: emailRecipients,
                    onSent: () async {
                      if (quote.state != QuoteState.approved) {
                        /// if already approved this is just a resend.
                        await DaoQuote().markQuoteSent(quote.id);
                        this.quote = (await DaoQuote().getById(quote.id))!;
                        setState(() {});
                      }
                    },
                  ),
                ),
              );
            }
          }
        },
      );

  Future<void> _editQuoteLine(BuildContext context, QuoteLine line) async {
    final editedLine = await showDialog<QuoteLine>(
      context: context,
      builder: (context) => EditQuoteLineDialog(line: line),
    );

    if (editedLine != null) {
      await DaoQuoteLine().update(editedLine);
      await DaoQuote().recalculateTotal(editedLine.quoteId);
      await widget.onEditQuote(quote);
    }
  }

  HMBButton _buildApprovedButton(Quote quote) => HMBButton(
        label: 'Approved',
        onPressed: () async {
          try {
            // Calls the DAO to update the state to "approved".
            await DaoQuote().approveQuote(quote.id);
            HMBToast.info('Quote approved successfully.');
            // Optionally, trigger a rebuild if needed.
            this.quote = (await DaoQuote().getById(quote.id))!;
            setState(() {});
          } catch (e) {
            HMBToast.error('Failed to approve quote: $e');
          }
        },
      );

  HMBButton _buildRejectedButton(Quote quote) => HMBButton(
        label: 'Rejected',
        onPressed: () async {
          try {
            // Calls the DAO to update the state to "rejected".
            await DaoQuote().rejectQuote(quote.id);
            HMBToast.info('Quote rejected successfully.');
            this.quote = (await DaoQuote().getById(quote.id))!;
            setState(() {});
          } catch (e) {
            HMBToast.error('Failed to reject quote: $e');
          }
        },
      );

  HMBButton _buildMilestonesButton(Quote quote) => HMBButton(
        label: 'Create Milestones',
        onPressed: () async {
          // Navigate to EditMilestonesScreen for milestone creation
          if (mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => EditMilestonesScreen(quoteId: quote.id),
              ),
            );
          }
        },
      );

  HMBButton _buildCreateInvoiceButton(Quote quote) => HMBButton(
        label: 'Create Invoice',
        onPressed: () async {
          try {
            final invoice = await createFixedPriceInvoice(quote);
            HMBToast.info('Invoice #${invoice.id} created successfully.');
          } catch (e) {
            HMBToast.error('Failed to create invoice: $e');
          }
        },
      );
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

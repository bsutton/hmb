// quote_details_screen.dart
import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao.g.dart';
import '../../entity/quote.dart';
import '../../entity/quote_line.dart';
import '../../util/format.dart';
import '../crud/milestone/edit_milestone_payment.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/media/pdf_preview.dart';
import '../widgets/surface.dart';
import 'edit_quote_line_dialog.dart';
import 'generate_quote_pdf.dart';
import 'job_quote.dart';

class QuoteDetailsScreen extends StatefulWidget {
  const QuoteDetailsScreen({required this.quoteId, super.key});
  final int quoteId;

  @override
  _QuoteDetailsScreenState createState() => _QuoteDetailsScreenState();
}

class _QuoteDetailsScreenState extends DeferredState<QuoteDetailsScreen> {
  late Quote _quote;

  @override
  Future<void> asyncInitState() async {
    _quote = await _loadQuote();
  }

  Future<Quote> _loadQuote() async =>
      (await DaoQuote().getById(widget.quoteId))!;

  Future<void> _refresh() async {
    await _loadQuote();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quote Details')),
    body: DeferredBuilder(
      this,
      builder:
          (context) => SingleChildScrollView(
            child: Surface(
              margin: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Quote Summary ---
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quote #${_quote.id}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('Issued: ${formatDate(_quote.createdDate)}'),
                        Text('Job ID: ${_quote.jobId}'),
                        Row(
                          children: [
                            Text('State: ${_quote.state.name}'),
                            const SizedBox(width: 8),
                            if (_quote.state == QuoteState.sent &&
                                _quote.dateSent != null)
                              Text('Sent: ${formatDate(_quote.dateSent!)}'),
                            if (_quote.state == QuoteState.approved &&
                                _quote.dateApproved != null)
                              Text(
                                'Approved: ${formatDate(_quote.dateApproved!)}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // --- Action Buttons ---
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        HMBButton(
                          label: 'Send...',
                          onPressed: () async {
                            var displayCosts = true;
                            var displayGroupHeaders = true;
                            var displayItems = true;
                            final result = await showDialog<Map<String, bool>>(
                              context: context,
                              builder: (context) {
                                var tempDisplayCosts = displayCosts;
                                var tempDisplayGroupHeaders =
                                    displayGroupHeaders;
                                var tempDisplayItems = displayItems;
                                return StatefulBuilder(
                                  builder:
                                      (context, setState) => AlertDialog(
                                        title: const Text(
                                          'Select Quote Options',
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CheckboxListTile(
                                              title: const Text(
                                                'Display Costs',
                                              ),
                                              value: tempDisplayCosts,
                                              onChanged: (value) {
                                                setState(() {
                                                  tempDisplayCosts =
                                                      value ?? true;
                                                });
                                              },
                                            ),
                                            CheckboxListTile(
                                              title: const Text(
                                                'Display Group Headers',
                                              ),
                                              value: tempDisplayGroupHeaders,
                                              onChanged: (value) {
                                                setState(() {
                                                  tempDisplayGroupHeaders =
                                                      value ?? true;
                                                });
                                              },
                                            ),
                                            CheckboxListTile(
                                              title: const Text(
                                                'Display Items',
                                              ),
                                              value: tempDisplayItems,
                                              onChanged: (value) {
                                                setState(() {
                                                  tempDisplayItems =
                                                      value ?? true;
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          HMBButton(
                                            label: 'Cancel',
                                            onPressed:
                                                () =>
                                                    Navigator.of(context).pop(),
                                          ),
                                          HMBButton(
                                            label: 'OK',
                                            onPressed: () {
                                              Navigator.of(context).pop({
                                                'displayCosts':
                                                    tempDisplayCosts,
                                                'displayGroupHeaders':
                                                    tempDisplayGroupHeaders,
                                                'displayItems':
                                                    tempDisplayItems,
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
                              displayGroupHeaders =
                                  result['displayGroupHeaders'] ?? true;
                              displayItems = result['displayItems'] ?? true;
                              final filePath = await generateQuotePdf(
                                _quote,
                                displayCosts: displayCosts,
                                displayGroupHeaders: displayGroupHeaders,
                                displayItems: displayItems,
                              );
                              final system = await DaoSystem().get();
                              final job = await DaoJob().getById(_quote.jobId);
                              final contacts = await DaoContact().getByJob(
                                _quote.jobId,
                              );
                              final emailRecipients =
                                  contacts.map((c) => c.emailAddress).toList();
                              if (context.mounted) {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder:
                                        (context) => PdfPreviewScreen(
                                          title:
                                              'Quote #${_quote.id} ${job!.summary}',
                                          filePath: filePath.path,
                                          emailSubject:
                                              '${system.businessName ?? 'Your'} Quote',
                                          emailBody:
                                              'Please find the attached quote',
                                          emailRecipients: emailRecipients,
                                          onSent: () async {
                                            if (_quote.state !=
                                                QuoteState.approved) {
                                              await DaoQuote().markQuoteSent(
                                                _quote.id,
                                              );
                                              await _loadQuote();
                                              setState(() {});
                                            }
                                          },
                                          canEmail:
                                              () async => EmailBlocked(
                                                blocked: false,
                                                reason: '',
                                              ),
                                        ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        HMBButton(
                          label: 'Create Milestones',
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder:
                                    (context) => EditMilestonesScreen(
                                      quoteId: _quote.id,
                                    ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        HMBButton(
                          label: 'Create Invoice',
                          onPressed: () async {
                            try {
                              final invoice = await createFixedPriceInvoice(
                                _quote,
                              );
                              HMBToast.info(
                                'Invoice #${invoice.id} created successfully.',
                              );
                            } catch (e) {
                              HMBToast.error('Failed to create invoice: $e');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // --- Quote Lines / Groups ---
                  FutureBuilderEx<JobQuote>(
                    // ignore: discarded_futures
                    future: JobQuote.fromQuoteId(_quote.id),
                    builder: (context, jobQuote) {
                      if (jobQuote == null || jobQuote.groups.isEmpty) {
                        return const ListTile(
                          title: Text('No quote lines found.'),
                        );
                      }
                      return Column(
                        children:
                            jobQuote.groups
                                .map(
                                  (group) => ExpansionTile(
                                    title: Text(
                                      '${group.group.name} - ${group.total}',
                                    ),
                                    children:
                                        group.lines
                                            .map(
                                              (line) => ListTile(
                                                title: Text(line.description),
                                                subtitle: Text(
                                                  'Quantity: ${line.quantity}, Unit Price: ${line.unitPrice}, Total: ${line.lineTotal}',
                                                ),
                                                onTap: () async {
                                                  final editedLine =
                                                      await showDialog<
                                                        QuoteLine
                                                      >(
                                                        context: context,
                                                        builder:
                                                            (context) =>
                                                                EditQuoteLineDialog(
                                                                  line: line,
                                                                ),
                                                      );
                                                  if (editedLine != null) {
                                                    await DaoQuoteLine().update(
                                                      editedLine,
                                                    );
                                                    await DaoQuote()
                                                        .recalculateTotal(
                                                          editedLine.quoteId,
                                                        );
                                                    await _refresh();
                                                  }
                                                },
                                              ),
                                            )
                                            .toList(),
                                  ),
                                )
                                .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
    ),
  );
}

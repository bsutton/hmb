import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../dao/_index.g.dart';
import '../entity/invoice_line.dart';
import '../entity/job.dart';
import '../entity/quote.dart';
import '../entity/quote_line.dart';
import '../invoicing/dialog_select_tasks.dart';
import '../util/format.dart';
import '../util/money_ex.dart';
import '../widgets/hmb_are_you_sure_dialog.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_one_of.dart';
import '../widgets/hmb_text_themes.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/pdf_preview.dart';
import 'edit_quote_line_dialog.dart';
import 'generate_quote_pdf.dart';
import 'job_quote.dart';

class QuoteListScreen extends StatefulWidget {
  const QuoteListScreen({
    required this.job,
    required this.emailRecipients,
    super.key,
  });
  final Job job;
  final List<String> emailRecipients;

  @override
  // ignore: library_private_types_in_public_api
  _QuoteListScreenState createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends State<QuoteListScreen> {
  late Future<List<Quote>> _quotes;
  late Future<bool> _hasQuoteableItems;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _quotes = DaoQuote().getByJobId(widget.job.id);
    // ignore: discarded_futures
    _hasQuoteableItems = DaoJob().hasQuoteableItems(widget.job);
  }

  Future<void> _createQuote() async {
    if (widget.job.hourlyRate == MoneyEx.zero) {
      HMBToast.error('Hourly rate must be set for job ${widget.job.summary}');
      return;
    }

    if (mounted) {
      final selectedTasks = await DialogTaskSelection.showQuote(
          context: context, job: widget.job);

      if (selectedTasks.isNotEmpty) {
        try {
          await DaoQuote().create(widget.job, selectedTasks);
          // ignore: avoid_catches_without_on_clauses
        } catch (e) {
          HMBToast.error('Failed to create quote: $e',
              acknowledgmentRequired: true);
        }
        await _refresh();
      }
    }
  }

  Future<void> _refresh() async {
    _quotes = DaoQuote().getByJobId(widget.job.id);
    _hasQuoteableItems = DaoJob().hasQuoteableItems(widget.job);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Quotes for Job: ${widget.job.summary}'),
        ),
        body: Column(
          children: [
            _buildCreateQuoteButton(),
            _buildQuoteList(),
          ],
        ),
      );

  Widget _buildQuoteList() => Expanded(
        child: FutureBuilderEx<List<Quote>>(
          future: _quotes,
          builder: (context, quotes) {
            if (quotes!.isEmpty) {
              return const Center(child: Text('No quotes found.'));
            }

            return ListView.builder(
              itemCount: quotes.length,
              itemBuilder: (context, index) {
                final quote = quotes[index];
                return _buildQuote(quote);
              },
            );
          },
        ),
      );

  Widget _buildQuote(Quote quote) => Container(
        color: Colors.grey[200],
        child: ExpansionTile(
          title: _buildQuoteTitle(quote),
          subtitle: Text('Total: ${quote.totalAmount}'),
          children: [
            FutureBuilderEx<JobQuote>(
              // ignore: discarded_futures
              future: JobQuote.fromQuoteId(quote.id),
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
                  _buildGenerateButton(quote),
                ],
              ),
            )
          ],
        ),
      );

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
            if (mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => PdfPreviewScreen(
                    title:
                        '''Quote #${quote.bestNumber} ${widget.job.summary}''',
                    filePath: filePath.path,
                    emailSubject: '${system!.businessName ?? 'Your'} quote',
                    emailBody: 'Please find the attached Quotation',
                    emailRecipients: widget.emailRecipients,
                  ),
                ),
              );
            }
          }
        },
        child: const Text('Generate and Preview PDF'),
      );

  Padding _buildQuoteGroup(JobQuote jobQuote) => Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(children: [
        for (final group in jobQuote.groups)
          ExpansionTile(
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
                ),
              _buildQuoteLine(group.lines, context)
            ],
          )
      ]));

  Widget _buildQuoteTitle(Quote quote) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: HMBTextHeadline(
                'Quote # ${quote.id} Issued: ${formatDate(quote.createdDate)}'),
          ),
          HMBButton(
              label: 'Delete',
              onPressed: () async => areYouSure(
                  context: context,
                  title: 'Delete Quote',
                  message: 'Are you sure you want to delete this quote?',
                  onConfirmed: () async {
                    try {
                      await DaoQuote().delete(quote.id);
                      await _refresh();
                      // ignore: avoid_catches_without_on_clauses
                    } catch (e) {
                      if (mounted) {
                        HMBToast.error(e.toString());
                      }
                    }
                  }))
        ],
      );

  Widget _buildQuoteLine(List<QuoteLine> quoteLines, BuildContext context) {
    final visibleLines = quoteLines
        .where((line) => line.status != LineStatus.noChargeHidden)
        .toList();
    return Column(
      children: visibleLines
          .map((line) => ListTile(
                title: Text(line.description),
                subtitle: Text(
                  '''Quantity: ${line.quantity}, Unit Price: ${line.unitPrice}, Status: ${line.status.toString().split('.').last}''',
                ),
                trailing: Text('Total: ${line.lineTotal}'),
                onTap: () async => _editQuoteLine(context, line),
              ))
          .toList(),
    );
  }

  FutureBuilderEx<bool> _buildCreateQuoteButton() => FutureBuilderEx<bool>(
        future: _hasQuoteableItems,
        builder: (context, hasUnbilledItems) => HMBOneOf(
            condition: hasUnbilledItems!,
            onTrue: Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton(
                onPressed: _createQuote,
                child: const Text('Create Quote'),
              ),
            ),
            onFalse: const Text('No billable Items found')),
      );

  Future<void> _editQuoteLine(BuildContext context, QuoteLine line) async {
    final editedLine = await showDialog<QuoteLine>(
      context: context,
      builder: (context) => EditQuoteLineDialog(line: line),
    );

    if (editedLine != null) {
      await DaoQuoteLine().update(editedLine);
      await DaoQuote().recalculateTotal(editedLine.quoteId);
      setState(() {
        _quotes = DaoQuote().getByJobId(widget.job.id);
      });
    }
  }
}

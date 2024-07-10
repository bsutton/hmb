import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../dao/dao_job.dart';
import '../dao/dao_quote.dart';
import '../dao/dao_quote_line.dart';
import '../dao/dao_quote_line_group.dart';
import '../entity/job.dart';
import '../entity/quote.dart';
import '../entity/quote_line.dart';
import '../entity/quote_line_group.dart';
import '../invoicing/dialog_select_tasks.dart';
import '../util/format.dart';
import '../util/money_ex.dart';
import '../widgets/hmb_are_you_sure_dialog.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_one_of.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/pdf_preview.dart';
import 'edit_quote_line_dialog.dart';
import 'generate_quote.dart';

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
  late Future<bool> _hasUnbilledItems;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _quotes = DaoQuote().getByJobId(widget.job.id);
    // ignore: discarded_futures
    _hasUnbilledItems = DaoJob().hasBillableTasks(widget.job);
  }

  Future<void> _createQuote() async {
    if (widget.job.hourlyRate == MoneyEx.zero) {
      HMBToast.error('Hourly rate must be set for job ${widget.job.summary}');
      return;
    }

    if (mounted) {
      final selectedTasks = await DialogTaskSelection.show(context, widget.job);

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
    _hasUnbilledItems = DaoJob().hasBillableTasks(widget.job);
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
            FutureBuilderEx<List<QuoteLineGroup>>(
              // ignore: discarded_futures
              future: DaoQuoteLineGroup().getByQuoteId(quote.id),
              builder: (context, quoteLineGroups) {
                if (quoteLineGroups!.isEmpty) {
                  return const ListTile(
                    title: Text('No quote lines found.'),
                  );
                }
                return _buildQuoteGroup(quoteLineGroups);
              },
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final filePath = await generateQuotePdf(quote);
                      if (mounted) {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => PdfPreviewScreen(
                              title:
                                  '''Quote #${quote.bestNumber} ${widget.job.summary}''',
                              filePath: filePath.path,
                              emailRecipients: widget.emailRecipients,
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Generate and Preview PDF'),
                  ),
                ],
              ),
            )
          ],
        ),
      );

  Padding _buildQuoteGroup(List<QuoteLineGroup> quoteLineGroups) => Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Column(
          children: quoteLineGroups
              .map((group) => ExpansionTile(
                    title: Text(group.name),
                    children: [
                      FutureBuilderEx<List<QuoteLine>>(
                        // ignore: discarded_futures
                        future: DaoQuoteLine().getByQuoteLineGroupId(group.id),
                        builder: (context, quoteLines) {
                          if (quoteLines!.isEmpty) {
                            return const ListTile(
                              title: Text('No quote lines found.'),
                            );
                          }
                          return _buildQuoteLine(quoteLines, context);
                        },
                      ),
                    ],
                  ))
              .toList(),
        ),
      );

  Widget _buildQuoteTitle(Quote quote) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Quote # ${quote.id} Issued: ${formatDate(quote.createdDate)}'),
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
        future: _hasUnbilledItems,
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

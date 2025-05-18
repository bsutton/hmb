import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao.g.dart';
import '../../entity/quote.dart';
import '../../entity/quote_line.dart';
import '../../entity/quote_line_group.dart';
import '../../util/format.dart';
import '../crud/milestone/edit_milestone_payment.dart';
import '../widgets/hmb_button.dart';
import '../widgets/surface.dart';
import 'edit_quote_line_dialog.dart';
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
    _quote = await _loadQuote();
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
                  _buildHeader(),
                  const Divider(),
                  _buildActions(),
                  const Divider(),
                  _buildQuoteLines(),
                ],
              ),
            ),
          ),
    ),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quote #${_quote.id}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text('Issued: ${formatDate(_quote.createdDate)}'),
        Text('Job ID: ${_quote.jobId}'),
        Row(
          children: [
            Text('State: ${_quote.state.name}'),
            const SizedBox(width: 8),
            if (_quote.state == QuoteState.sent && _quote.dateSent != null)
              Text('Sent: ${formatDate(_quote.dateSent!)}'),
            if (_quote.state == QuoteState.approved &&
                _quote.dateApproved != null)
              Text('Approved: ${formatDate(_quote.dateApproved!)}'),
          ],
        ),
      ],
    ),
  );

  Widget _buildActions() => Padding(
    padding: const EdgeInsets.all(8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        HMBButton(label: 'Send...', onPressed: _sendQuote),
        HMBButton(
          label: 'Create Milestones',
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EditMilestonesScreen(quoteId: _quote.id),
              ),
            );
          },
        ),
        HMBButton(label: 'Create Invoice', onPressed: _createInvoice),
      ],
    ),
  );

  Widget _buildQuoteLines() => FutureBuilderEx<JobQuote>(
    future: JobQuote.fromQuoteId(_quote.id),
    builder: (context, jobQuote) {
      if (jobQuote == null || jobQuote.groups.isEmpty) {
        return const ListTile(title: Text('No quote lines found.'));
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            jobQuote.groups.map((groupWrap) {
              final group = groupWrap.group;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // —— Group header with Reject button ——
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (group.taskId != null &&
                            group.lineApprovalStatus !=
                                LineApprovalStatus.rejected)
                          HMBButton(
                            label: 'Reject',
                            onPressed:
                                () => _rejectQuoteGroup(group, groupWrap.lines),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // —— Lines list ——
                    Card(
                      child: Column(
                        children:
                            groupWrap.lines
                                .map(
                                  (line) => ListTile(
                                    title: Text(line.description),
                                    subtitle: Text(
                                      'Qty: ${line.quantity} × ${line.unitCharge} = '
                                      '${line.lineTotal}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () async {
                                        final editedLine =
                                            await showDialog<QuoteLine>(
                                              context: context,
                                              builder:
                                                  (_) => EditQuoteLineDialog(
                                                    line: line,
                                                  ),
                                            );
                                        if (editedLine != null) {
                                          await DaoQuoteLine().update(
                                            editedLine,
                                          );
                                          await DaoQuote().recalculateTotal(
                                            editedLine.quoteId,
                                          );
                                          await _refresh();
                                        }
                                      },
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      );
    },
  );

  Future<void> _sendQuote() async {
    // … your existing send‐quote code unchanged …
  }

  Future<void> _createInvoice() async {
    // … your existing create‐invoice code unchanged …
  }

  Future<void> _rejectQuoteGroup(
    QuoteLineGroup group,
    List<QuoteLine> lines,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        var alsoRejectTask = false;
        return AlertDialog(
          title: const Text('Reject Quote Group'),
          content: StatefulBuilder(
            builder:
                (context, setState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Do you want to reject this group of items?'),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text(
                        'Also mark the associated task as rejected',
                      ),
                      value: alsoRejectTask,
                      onChanged:
                          (v) => setState(() {
                            alsoRejectTask = v ?? false;
                          }),
                    ),
                  ],
                ),
          ),
          actions: [
            HMBButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(context, false),
            ),
            HMBButton(
              label: 'Reject',
              onPressed: () => Navigator.pop(context, alsoRejectTask),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    // 1) Mark the group rejected in the DB
    await DaoQuoteLineGroup().update(
      group.copyWith(lineApprovalStatus: LineApprovalStatus.rejected),
    );

    // 2) Optionally mark the task rejected
    if (group.taskId != null) {
      await DaoTask().markRejected(group.taskId!);
    }

    // 3) Recalculate and refresh
    await DaoQuote().recalculateTotal(group.quoteId);
    await _refresh();
  }
}

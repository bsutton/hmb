// quote_list_screen.dart

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/format.dart';
import '../crud/job/edit_job_screen.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/widgets.g.dart';
import 'job_and_customer.dart';

class QuoteCard extends StatefulWidget {
  const QuoteCard({
    required this.quote,
    required this.onDelete,
    required this.onStateChanged,
    super.key,
  });
  final Quote quote;
  final VoidCallback onDelete;
  final ValueChanged<Quote> onStateChanged;

  @override
  _QuoteCardState createState() => _QuoteCardState();
}

class _QuoteCardState extends DeferredState<QuoteCard> {
  late Quote quote;
  late JobAndCustomer jc;

  @override
  Future<void> asyncInitState() async {
    quote = widget.quote;
    jc = await JobAndCustomer.fromQuote(quote);
  }

  Future<void> _updateQuote(Future<void> Function() action) async {
    try {
      await action();
      HMBToast.info('Quote #${quote.id} updated.');
      // Notify the parent to remove this quote.
      widget.onStateChanged(quote);
    } catch (e) {
      HMBToast.error('Failed to update quote: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(8),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: DeferredBuilder(
        this,
        builder:
            (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with summary info and delete icon.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Quote #${quote.id} - Issued: ${formatDate(quote.createdDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
                // Additional details.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HMBLinkInternal(
                          label: 'Job: #${quote.jobId}',
                          navigateTo: () async {
                            final job = await DaoJob().getById(quote.jobId);
                            return JobEditScreen(job: job);
                          },
                        ),
                        const HMBSpacer(width: true),
                        Text(jc.job.summary),
                      ],
                    ),
                    Text('Customer: ${jc.customer.name}'),
                    Text('Contact: ${jc.contact?.fullname ?? 'N/A'}'),
                  ],
                ),
                // Display current state and date info.
                Row(
                  children: [
                    Text(quote.state.name.toCapitalised()),
                    const SizedBox(width: 8),
                    if (quote.state == QuoteState.sent &&
                        quote.dateSent != null)
                      Text('Sent: ${formatDate(quote.dateSent!)}'),
                    if (quote.state == QuoteState.approved &&
                        quote.dateApproved != null)
                      Text(formatDate(quote.dateApproved!)),
                  ],
                ),
                // --- State Update Buttons ---
                Row(
                  children: [
                    HMBButton(
                      label: 'Approved',
                      onPressed: () async {
                        await _updateQuote(() async {
                          await DaoQuote().approveQuote(quote.id);
                          quote = (await DaoQuote().getById(quote.id))!;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    HMBButton(
                      label: 'Rejected',
                      onPressed: () async {
                        await _updateQuote(() async {
                          await DaoQuote().rejectQuote(quote.id);
                          quote = (await DaoQuote().getById(quote.id))!;
                        });
                      },
                    ),
                  ],
                ),
                // --- End State Buttons ---
              ],
            ),
      ),
    ),
  );
}

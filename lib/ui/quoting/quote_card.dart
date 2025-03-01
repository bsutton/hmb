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
import 'list_quote_screen.dart';

/// A summary card used in the list screen.
class QuoteSummaryCard extends StatefulWidget {
  const QuoteSummaryCard({
    required this.quote,
    required this.onDelete,
    required this.onStateChanged,
    super.key,
  });
  final Quote quote;
  final VoidCallback onDelete;
  final VoidCallback onStateChanged;

  @override
  _QuoteSummaryCardState createState() => _QuoteSummaryCardState();
}

class _QuoteSummaryCardState extends DeferredState<QuoteSummaryCard> {
  late Quote quote;

  late JobAndCustomer jc;
  @override
  Future<void> asyncInitState() async {
    quote = widget.quote;
    jc = await JobAndCustomer.fromQuote(quote);
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
                // Header row with summary information and a delete icon.
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

                // Display the current state and (if set) date information.
                Row(
                  children: [
                    Text(quote.state.name.toCapitalised()),
                    const SizedBox(width: 8),
                    if (quote.state.name == 'sent' && quote.dateSent != null)
                      Text('Sent: ${formatDate(quote.dateSent!)}'),
                    if (quote.state.name == 'approved' &&
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
                        try {
                          await DaoQuote().approveQuote(quote.id);
                          HMBToast.info('Quote approved.');
                          quote = (await DaoQuote().getById(quote.id))!;
                          setState(() {});
                          widget.onStateChanged();
                        } catch (e) {
                          HMBToast.error('Failed to approve quote: $e');
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    HMBButton(
                      label: 'Rejected',
                      onPressed: () async {
                        try {
                          await DaoQuote().rejectQuote(quote.id);
                          HMBToast.info('Quote rejected.');
                          quote = (await DaoQuote().getById(quote.id))!;
                          setState(() {});
                          widget.onStateChanged();
                        } catch (e) {
                          HMBToast.error('Failed to reject quote: $e');
                        }
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

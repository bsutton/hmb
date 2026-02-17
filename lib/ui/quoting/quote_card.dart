/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// quote_list_screen.dart

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/dart/format.dart';
import '../../util/dart/types.dart';
import '../crud/job/full_page_list_job_card.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/widgets.g.dart';
import 'job_and_customer.dart';
import 'quote_details_screen.dart';

enum _RejectAction { quoteOnly, quoteAndJob }

class QuoteCard extends StatefulWidget {
  final Quote quote;
  final ValueChanged<Quote> onStateChanged;

  const QuoteCard({
    required this.quote,
    required this.onStateChanged,
    super.key,
  });

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

  Future<void> _updateQuote(AsyncVoidCallback action) async {
    try {
      await action();
      quote = (await DaoQuote().getById(quote.id))!;
      HMBToast.info('Quote #${quote.id} updated.');
      // Notify the parent to remove this quote.
      widget.onStateChanged(quote);
    } catch (e) {
      HMBToast.error('Failed to update quote: $e');
    }
  }

  Future<void> _openQuoteDetails(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuoteDetailsScreen(quoteId: quote.id),
      ),
    );
    quote = (await DaoQuote().getById(quote.id))!;
    widget.onStateChanged(quote);
    if (mounted) {
      setState(() {});
    }
  }

  Future<_RejectAction?> _promptRejectAction(BuildContext context) =>
      showDialog<_RejectAction>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject Quote'),
          content: const Text('Do you want to reject the job as well?'),
          actions: [
            HMBButton(
              label: 'Cancel',
              hint: 'Keep the quote unchanged',
              onPressed: () => Navigator.pop(context),
            ),
            HMBButton(
              label: 'Quote Only',
              hint: 'Reject the quote but keep the job active',
              onPressed: () => Navigator.pop(context, _RejectAction.quoteOnly),
            ),
            HMBButton(
              label: 'Quote + Job',
              hint: 'Reject the quote and the job',
              onPressed: () =>
                  Navigator.pop(context, _RejectAction.quoteAndJob),
            ),
          ],
        ),
      );

  Future<bool?> _promptWithdraw(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Withdraw Quote'),
      content: const Text('Withdraw this quote?'),
      actions: [
        HMBButton(
          label: 'Cancel',
          hint: 'Keep the quote unchanged',
          onPressed: () => Navigator.pop(context, false),
        ),
        HMBButton(
          label: 'Withdraw',
          hint: 'Mark the quote as withdrawn',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isApproved = quote.state == QuoteState.approved;
    final isRejected = quote.state == QuoteState.rejected;
    final isWithdrawn = quote.state == QuoteState.withdrawn;
    final showSentRollback = quote.state == QuoteState.approved;
    final showWithdrawn = quote.state == QuoteState.sent;
    final canManageMilestonesOrInvoice = quote.state.isPostApproval;

    return DeferredBuilder(
      this,
      builder: (context) => HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // details.
          HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HMBLinkInternal(
                    label: 'Job: #${quote.jobId}',
                    navigateTo: () async {
                      final job = await DaoJob().getById(quote.jobId);
                      return FullPageListJobCard(job!);
                    },
                  ),
                  const HMBSpacer(width: true),
                  Text(jc.job.summary),
                ],
              ),
              Text('Customer: ${jc.customer.name}'),
              Text('Primary Contact: ${jc.primaryContact?.fullname ?? 'N/A'}'),
              Text('Billing Contact: ${jc.billingContact?.fullname ?? 'N/A'}'),
              Text('Total: ${quote.totalAmount}'),
            ],
          ),
          // Display current state and date info.
          HMBRow(
            children: [
              Text(quote.state.name.toCapitalised()),
              if (quote.state == QuoteState.sent && quote.dateSent != null)
                Text('Sent: ${formatDate(quote.dateSent!)}'),
              if (quote.state == QuoteState.approved &&
                  quote.dateApproved != null)
                Text(formatDate(quote.dateApproved!)),
            ],
          ),

          HMBRow(
            children: [
              HMBButton(
                label: 'Send...',
                hint: 'Open quote details to send this quote',
                enabled: !isRejected && !isWithdrawn,
                onPressed: () async => _openQuoteDetails(context),
              ),
              HMBButton(
                label: 'Milestones',
                hint: 'Open quote details to create milestone payments',
                enabled: canManageMilestonesOrInvoice,
                onPressed: () async => _openQuoteDetails(context),
              ),
              HMBButton(
                label: 'Invoice',
                hint: 'Open quote details to create an invoice',
                enabled: canManageMilestonesOrInvoice,
                onPressed: () async => _openQuoteDetails(context),
              ),
            ],
          ),

          // --- State Update Buttons ---
          HMBRow(
            children: [
              HMBButton(
                label: showSentRollback ? 'Unapprove' : 'Approved',
                hint: showSentRollback
                    ? 'Move approved quote back to sent'
                    : 'Mark the quote as approved by the customer',
                enabled: showSentRollback || (!isApproved && !isWithdrawn),
                onPressed: () async {
                  await _updateQuote(() async {
                    if (showSentRollback) {
                      await DaoQuote().markQuoteSent(quote.id);
                    } else {
                      await DaoQuote().approveQuote(quote.id);
                    }
                  });
                },
              ),
              HMBButton(
                label: 'Rejected',
                hint: 'Mark the quote as rejected',
                // disable when already rejected
                enabled: !isRejected && !isWithdrawn,
                onPressed: () async {
                  final action = await _promptRejectAction(context);
                  if (action == null) {
                    return;
                  }

                  await _updateQuote(() async {
                    await DaoQuote().rejectQuote(quote.id);

                    if (action == _RejectAction.quoteAndJob) {
                      final job = await DaoJob().getById(quote.jobId);
                      if (job != null) {
                        job.status = JobStatus.rejected;
                        await DaoJob().update(job);
                      }
                    }
                  });
                },
              ),
              if (showWithdrawn)
                HMBButton(
                  label: 'Withdrawn',
                  hint: 'Mark the quote as withdrawn by your business',
                  onPressed: () async {
                    final confirm = await _promptWithdraw(context);
                    if (confirm != true) {
                      return;
                    }
                    await _updateQuote(() async {
                      await DaoQuote().withdrawQuote(quote.id);
                    });
                  },
                ),
            ],
          ),
          // --- End State Buttons ---
        ],
      ),
    );
  }
}

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
import '../crud/job/edit_job_screen.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/widgets.g.dart';
import 'job_and_customer.dart';

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

  @override
  Widget build(BuildContext context) {
    final isApproved = quote.state == QuoteState.approved;
    final isRejected = quote.state == QuoteState.rejected;

    return DeferredBuilder(
      this,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // details.
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
              Text('Primary Contact: ${jc.primaryContact?.fullname ?? 'N/A'}'),
              Text('Billing Contact: ${jc.billingContact?.fullname ?? 'N/A'}'),
              Text('Total: ${quote.totalAmount}'),
            ],
          ),
          // Display current state and date info.
          Row(
            children: [
              Text(quote.state.name.toCapitalised()),
              const SizedBox(width: 8),
              if (quote.state == QuoteState.sent && quote.dateSent != null)
                Text('Sent: ${formatDate(quote.dateSent!)}'),
              if (quote.state == QuoteState.approved &&
                  quote.dateApproved != null)
                Text(formatDate(quote.dateApproved!)),
            ],
          ),
          const HMBSpacer(height: true),

          // --- State Update Buttons ---
          Row(
            children: [
              HMBButton(
                label: 'Approved',
                hint: 'Mark the quote as approved by the customer',
                // disable when already approved
                enabled: !isApproved,
                onPressed: () async {
                  await _updateQuote(() async {
                    await DaoQuote().approveQuote(quote.id);
                  });
                },
              ),
              const SizedBox(width: 8),
              HMBButton(
                label: 'Rejected',
                hint: 'Mark the quote as rejected',
                // disable when already rejected
                enabled: !isRejected,
                onPressed: () async {
                  await _updateQuote(() async {
                    await DaoQuote().rejectQuote(quote.id);
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

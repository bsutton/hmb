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

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../../dao/dao.g.dart';
import '../../entity/quote.dart';
import '../../util/dart/format.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/layout/surface.dart';
import '../widgets/text/hmb_text_themes.dart';
import 'quote_details.dart';

class QuoteDetailsScreen extends StatefulWidget {
  final int quoteId;

  const QuoteDetailsScreen({required this.quoteId, super.key});

  @override
  _QuoteDetailsScreenState createState() => _QuoteDetailsScreenState();
}

class _QuoteDetailsScreenState extends DeferredState<QuoteDetailsScreen> {
  late var _quote = Quote.forInsert(
    jobId: 1,
    summary: '',
    description: '',
    totalAmount: Money.fromInt(0, isoCode: 'USD'),
  );

  @override
  Future<void> asyncInitState() async {
    _quote = await _loadQuote();
  }

  Future<Quote> _loadQuote() async {
    final quote = (await DaoQuote().getById(widget.quoteId))!;
    return quote;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quote Details')),
    body: DeferredBuilder(
      this,
      builder: (context) => SingleChildScrollView(
        child: Surface(
          margin: const EdgeInsets.all(8),
          child: HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildHeader(), const Divider(), _buildQuoteLines()],
          ),
        ),
      ),
    ),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.all(8),
    child: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quote #${_quote.id}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text('Issued: ${formatDate(_quote.createdDate)}'),
        Text('Job ID: ${_quote.jobId}'),
        HMBRow(
          children: [
            Text('State: ${_quote.state.name}'),
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

  Widget _buildQuoteLines() => FutureBuilderEx<QuoteDetails>(
    future: QuoteDetails.fromQuoteId(_quote.id, excludeHidden: false),
    debugLabel: 'QuoteDetailsScreen:_buildQuoteLines',
    builder: (context, jobQuote) {
      if (jobQuote == null || jobQuote.groups.isEmpty) {
        return const ListTile(title: Text('No quote lines found.'));
      }

      return HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: jobQuote.groups.map((groupWrap) {
          final group = groupWrap.group;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: HMBColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: HMBTextLine(
                        'Task: ${group.name} ${groupWrap.total}',
                      ),
                    ),
                  ],
                ),
                Card(
                  child: HMBColumn(
                    children: groupWrap.lines
                        .map(
                          (line) => ListTile(
                            title: Text(line.description),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '''Qty: ${line.quantity} × ${line.unitCharge} = '''
                                  '${line.lineTotal}',
                                ),
                                Text(
                                  '''Status: ${line.lineChargeableStatus.description}''',
                                ),
                              ],
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
}

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
import 'package:strings/strings.dart';

import '../../../../dao/dao_customer.dart';
import '../../../../dao/dao_job.dart';
import '../../../../dao/dao_milestone.dart';
import '../../../../dao/dao_quote.dart';
import '../../../../entity/customer.dart';
import '../../../../entity/job.dart';
import '../../../../entity/milestone.dart';
import '../../../../entity/quote.dart';
import '../../../util/flutter/flutter_util.g.dart';
import '../../quoting/select_quote_dialog.dart';
import '../../widgets/layout/hmb_list_page.dart';
import 'edit_milestone_payment.dart';

class ListMilestoneScreen extends StatefulWidget {
  const ListMilestoneScreen({super.key});

  @override
  _ListMilestoneScreenState createState() => _ListMilestoneScreenState();
}

class _ListMilestoneScreenState extends DeferredState<ListMilestoneScreen> {
  late Future<List<QuoteMilestoneSummary>> _summaries;

  String? filter;

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Milestones');
    _summaries = _fetchMilestoneSummaries();
  }

  Future<List<QuoteMilestoneSummary>> _fetchMilestoneSummaries() async {
    final milestones = await DaoMilestone().getAll();
    if (milestones.isEmpty) {
      return [];
    }

    // Group milestones by quote_id
    final milestonesByQuote = <int, List<Milestone>>{};
    for (final m in milestones) {
      milestonesByQuote.putIfAbsent(m.quoteId, () => []).add(m);
    }

    final summaries = <QuoteMilestoneSummary>[];

    for (final entry in milestonesByQuote.entries) {
      final quoteId = entry.key;
      final quote = await DaoQuote().getById(quoteId);
      if (quote == null) {
        continue;
      }

      final job = await DaoJob().getById(quote.jobId);
      if (job == null) {
        continue;
      }

      Customer? customer;
      if (job.customerId != null) {
        customer = await DaoCustomer().getById(job.customerId);
      }

      final quoteMilestones = entry.value;
      final activeMilestones = quoteMilestones.where((m) => !m.voided).toList();

      // Total value of active milestones
      final totalValue = activeMilestones.fold<Money>(
        MoneyEx.zero,
        (sum, m) => sum + (m.paymentAmount),
      );

      final count = activeMilestones.length;
      final voidedCount = quoteMilestones.length - count;

      // Calculate total invoiced to date (active only)
      final invoicedValue = activeMilestones.fold<Money>(
        MoneyEx.zero,
        (sum, m) =>
            sum + ((m.invoiceId != null) ? m.paymentAmount : MoneyEx.zero),
      );

      // Count how many milestones are invoiced (active only)
      final invoicedCount = activeMilestones
          .where((m) => m.invoiceId != null)
          .length;

      final summary = QuoteMilestoneSummary(
        quote: quote,
        job: job,
        customer: customer,
        totalValue: totalValue,
        milestoneCount: count,
        invoicedValue: invoicedValue,
        invoicedCount: invoicedCount,
        voidedCount: voidedCount,
      );
      if (summary.matches(filter)) {
        summaries.add(summary);
      }
    }

    return summaries;
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilderEx<List<QuoteMilestoneSummary>>(
    future: _summaries,
    builder: (_, summaries) => HMBListPage(
      emptyMessage:
          'No milestones found - create milestone payments from the Billing/Quote screen.',
      itemCount: summaries!.length,
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return _buildMilestoneSummaryCard(summary);
      },
      onSearch: (filter) {
        this.filter = filter?.toLowerCase();
        _summaries = _fetchMilestoneSummaries();
        setState(() {});
      },
      onAdd: _createMilestone,
    ),
  );

  Widget _buildMilestoneSummaryCard(QuoteMilestoneSummary summary) =>
      HMBListCard(
        title: summary.job.summary,
        children: [
          Text('Customer: ${summary.customer?.name ?? "N/A"}'),
          Text('Job #: ${summary.job.id}'),
          Text('Quote #: ${summary.quote.bestNumber}'),
          Text('Milestones: ${summary.milestoneCount}'),
          Text('Invoiced Milestones: ${summary.invoicedCount}'),
          Text('Voided Milestones: ${summary.voidedCount}'),
          Text('Invoiced to date: ${summary.invoicedValue}'),
          Text('Total Value: ${summary.totalValue}'),
        ],
        onTap: () async {
          // Navigate to EditMilestonesScreen for this quote
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) =>
                  EditMilestonesScreen(quoteId: summary.quote.id),
            ),
          );
          setState(() {
            _summaries = _fetchMilestoneSummaries();
          });
        },
      );

  Future<void> _createMilestone() async {
    final quote = await SelectQuoteDialog.show(context);
    if (mounted && quote != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => EditMilestonesScreen(quoteId: quote.id),
        ),
      );
      setState(() {
        _summaries = _fetchMilestoneSummaries();
      });
    }
  }
}

class QuoteMilestoneSummary {
  final Quote quote;
  final Job job;
  final Customer? customer;
  final Money totalValue;
  final int milestoneCount;
  final Money invoicedValue;
  final int invoicedCount;
  final int voidedCount;

  QuoteMilestoneSummary({
    required this.quote,
    required this.job,
    required this.customer,
    required this.totalValue,
    required this.milestoneCount,
    required this.invoicedValue,
    required this.invoicedCount,
    required this.voidedCount,
  });

  bool matches(String? filter) {
    if (Strings.isBlank(filter)) {
      return true;
    }

    if (customer?.name.toLowerCase().contains(filter!) ?? false) {
      return true;
    }

    if (job.summary.toLowerCase().contains(filter!)) {
      return true;
    }

    return false;
  }
}

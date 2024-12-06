import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../../../../dao/dao_customer.dart';
import '../../../../dao/dao_job.dart';
import '../../../../dao/dao_milestone.dart';
import '../../../../dao/dao_quote.dart';
import '../../../../entity/customer.dart';
import '../../../../entity/job.dart';
import '../../../../entity/milestone.dart';
import '../../../../entity/quote.dart';
import '../../../../util/money_ex.dart';
import 'edit_milestone_payment.dart';

class MilestoneOverviewScreen extends StatefulWidget {
  const MilestoneOverviewScreen({super.key});

  @override
  _MilestoneOverviewScreenState createState() =>
      _MilestoneOverviewScreenState();
}

class _MilestoneOverviewScreenState extends State<MilestoneOverviewScreen> {
  late Future<List<QuoteMilestoneSummary>> _summaries;

  @override
  void initState() {
    super.initState();
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
      final totalValue = quoteMilestones.fold<Money>(
          MoneyEx.zero, (sum, m) => sum + (m.paymentAmount ?? MoneyEx.zero));
      final count = quoteMilestones.length;

      summaries.add(QuoteMilestoneSummary(
        quote: quote,
        job: job,
        customer: customer,
        totalValue: totalValue,
        milestoneCount: count,
      ));
    }

    return summaries;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Milestone Overview'),
        ),
        body: FutureBuilderEx<List<QuoteMilestoneSummary>>(
          future: _summaries,
          builder: (context, summaries) {
            if (summaries == null || summaries.isEmpty) {
              return const Center(
                  child: Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                    'No milestones found - create milestone payments from the Billing/Quote screen.'),
              ));
            }

            return ListView.builder(
              itemCount: summaries.length,
              itemBuilder: (context, index) {
                final summary = summaries[index];
                return _buildMilestoneSummaryCard(summary);
              },
            );
          },
        ),
      );

  Widget _buildMilestoneSummaryCard(QuoteMilestoneSummary summary) => Card(
        margin: const EdgeInsets.all(8),
        child: ListTile(
          title: Text(
            summary.job.summary,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${summary.customer?.name ?? "N/A"}'),
              Text('Job #: ${summary.job.id}'),
              Text('Milestones: ${summary.milestoneCount}'),
              Text('Total Value: ${summary.totalValue}'),
              Text('Quote #: ${summary.quote.bestNumber}'),
            ],
          ),
          onTap: () async {
            // Navigate to EditMilestonesScreen for this quote
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => EditMilestonesScreen(
                  quoteId: summary.quote.id,
                ),
              ),
            );
            setState(() {
              _summaries = _fetchMilestoneSummaries();
            });
          },
        ),
      );
}

class QuoteMilestoneSummary {
  QuoteMilestoneSummary({
    required this.quote,
    required this.job,
    required this.customer,
    required this.totalValue,
    required this.milestoneCount,
  });

  final Quote quote;
  final Job job;
  final Customer? customer;
  final Money totalValue;
  final int milestoneCount;
}

// lib/src/ui/dashboard/billing_dashboard_page.dart
import 'package:flutter/material.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/util.g.dart';
import 'nav.g.dart';

class BillingDashboardPage extends StatelessWidget {
  const BillingDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Billing')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          DashletCard<void>(
            label: 'Estimator',
            icon: Icons.calculate,
            dashletValue: () => Future.value(const DashletValue(null)),
            route: '/billing/estimator',
            widgetBuilder: (_, _) => const SizedBox.shrink(),
          ),
          DashletCard<String>(
            label: 'Quotes',
            icon: Icons.format_quote,
            // ignore: discarded_futures
            dashletValue: getQuoteValue,
            route: '/billing/quotes',
          ),
          DashletCard<int>(
            label: 'To Be Invoiced',
            icon: Icons.attach_money,
            // ignore: discarded_futures
            dashletValue: getYetToBeInvoiced,
            route: '/billing/to_be_invoiced',
          ),
          DashletCard<String>(
            label: 'Invoices',
            icon: Icons.receipt_long,
            // ignore: discarded_futures
            dashletValue: getInvoicedThisMonth,
            route: '/billing/invoices',
          ),
          DashletCard<void>(
            label: 'Milestones',
            icon: Icons.flag,
            dashletValue: () => Future.value(const DashletValue(null)),
            route: '/billing/milestones',
            widgetBuilder: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
  Future<DashletValue<String>> getQuoteValue() async {
    final quotes = await DaoQuote().getAll();
    var total = MoneyEx.zero;
    for (final q in quotes) {
      if (q.state == QuoteState.sent || q.state == QuoteState.approved) {
        total += q.totalAmount;
      }
    }
    return DashletValue(total.format('S#'));
  }

  Future<DashletValue<int>> getYetToBeInvoiced() async {
    final jobs = await DaoJob().readyToBeInvoiced(null);
    final count = jobs.length;
    var total = MoneyEx.zero;
    for (final job in jobs) {
      final hourlyRate = job.hourlyRate;
      final statistics = await DaoJob().getJobStatistics(job);
      total +=
          statistics.completedMaterialCost +
          (hourlyRate!.multiplyByFixed(statistics.workedHours));
    }
    return DashletValue(count, total.format('S#'));
  }

  Future<DashletValue<String>> getInvoicedThisMonth() async {
    final invoices = await DaoInvoice().getAll();
    final now = DateTime.now();
    var total = MoneyEx.zero;
    for (final inv in invoices) {
      if (inv.sent &&
          inv.createdDate.year == now.year &&
          inv.createdDate.month == now.month) {
        total += inv.totalAmount;
      }
    }
    return DashletValue(total.format('S#'));
  }
}

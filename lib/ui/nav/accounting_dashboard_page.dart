// lib/src/ui/dashboard/billing_dashboard_page.dart
import 'package:flutter/material.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/util.g.dart';
import 'dashlets/invoices.dart';
import 'dashlets/receipt.dart';
import 'nav.g.dart';

class AccountingDashboardPage extends StatelessWidget {
  const AccountingDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => DashboardPage(
    title: 'Accounting',
    dashlets: [
      DashletCard<void>(
        label: 'Estimator',
        icon: Icons.calculate,
        dashletValue: () => Future.value(const DashletValue(null)),
        route: '/accounting/estimator',
        widgetBuilder: (_, _) => const SizedBox.shrink(),
      ),
      DashletCard<String>(
        label: 'Quotes',
        icon: Icons.format_quote,
        // ignore: discarded_futures
        dashletValue: getQuoteValue,
        route: '/accounting/quotes',
      ),
      DashletCard<int>(
        label: 'To Be Invoiced',
        icon: Icons.attach_money,
        // ignore: discarded_futures
        dashletValue: getYetToBeInvoiced,
        route: '/accounting/to_be_invoiced',
      ),
      const InvoiceDashlet(),
      DashletCard<void>(
        label: 'Milestones',
        icon: Icons.flag,
        dashletValue: () async => const DashletValue<String>('fixed price'),
        route: '/accounting/milestones',
      ),
      const ReceiptDashlet(),
    ],
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
}

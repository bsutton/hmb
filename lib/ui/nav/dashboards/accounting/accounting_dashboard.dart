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

// lib/src/ui/dashboard/billing_dashboard_page.dart
import 'package:flutter/material.dart';

import '../../../../dao/dao.g.dart';
import '../../../../entity/entity.g.dart';
import '../../../../util/flutter/flutter_util.g.dart';
import '../dashboard.dart';
import '../dashlet_card.dart';
import 'invoices.dart';
import 'receipt.dart';

class AccountingDashboardPage extends StatelessWidget {
  const AccountingDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => DashboardPage(
    title: 'Accounting',
    dashlets: [
      DashletCard<void>.route(
        label: 'Estimator',
        hint:
            'Create estimates for a Job by adding Tasks, Labour and Materials',
        icon: Icons.calculate,
        value: () => Future.value(const DashletValue(null)),
        route: '/home/accounting/estimator',
        valueBuilder: (_, _) => const SizedBox.shrink(),
      ),
      DashletCard<String>.route(
        label: 'Quotes',
        hint: 'Quote a Job based on an Estimate',
        icon: Icons.format_quote,
        value: getQuoteValue,
        route: '/home/accounting/quotes',
      ),
      DashletCard<int>.route(
        label: 'To Be Invoiced',
        hint: 'List of Jobs that have unbilled hours',
        icon: Icons.attach_money,
        value: getYetToBeInvoiced,
        route: '/home/accounting/to_be_invoiced',
      ),
      const InvoiceDashlet(),
      DashletCard<void>.route(
        label: 'Milestones',
        hint: 'Create and Invoice Milestone Payments for Fixed price Jobs',
        icon: Icons.flag,
        value: () async => const DashletValue<String>('fixed price'),
        route: '/home/accounting/milestones',
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

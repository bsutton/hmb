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

import 'package:flutter/material.dart';

import '../../../widgets/layout/layout.g.dart';
import '../dashboard.dart';
import '../dashlet_card.dart';

class AccountingReportsDashboardPage extends StatelessWidget {
  const AccountingReportsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => DashboardPage(
    title: 'Accounting Reports',
    dashlets: [
      DashletCard<void>.route(
        label: 'Tax Pack',
        hint: 'Email a bundled accountant report pack for tax time',
        icon: Icons.folder_zip,
        value: () async => const DashletValue(null),
        route: '/home/accounting/reports/tax_pack',
        valueBuilder: (_, _) => const HMBEmpty(),
      ),
      DashletCard<void>.route(
        label: 'P&L',
        hint: 'Show income, costs and profit for a selected period',
        icon: Icons.summarize,
        value: () async => const DashletValue(null),
        route: '/home/accounting/profit_and_loss',
        valueBuilder: (_, _) => const HMBEmpty(),
      ),
      DashletCard<void>.route(
        label: 'Tax Summary',
        hint: 'Show configured tax collected and paid',
        icon: Icons.receipt_long,
        value: () async => const DashletValue(null),
        route: '/home/accounting/tax_summary',
        valueBuilder: (_, _) => const HMBEmpty(),
      ),
      DashletCard<void>.route(
        label: 'Customer Payments',
        hint: 'Export customer payments for a selected period',
        icon: Icons.payments,
        value: () async => const DashletValue(null),
        route: '/home/accounting/cash_received',
        valueBuilder: (_, _) => const HMBEmpty(),
      ),
      DashletCard<void>.route(
        label: 'Supplier Spend',
        hint: 'Show receipt spend grouped by supplier',
        icon: Icons.store,
        value: () async => const DashletValue(null),
        route: '/home/accounting/supplier_spend',
        valueBuilder: (_, _) => const HMBEmpty(),
      ),
      DashletCard<void>.route(
        label: 'Unlinked Costs',
        hint: 'Find receipts not linked to task items',
        icon: Icons.link_off,
        value: () async => const DashletValue(null),
        route: '/home/accounting/unlinked_costs',
        valueBuilder: (_, _) => const HMBEmpty(),
      ),
      DashletCard<void>.route(
        label: 'Aged Receivables',
        hint: 'Show outstanding invoice balances by age',
        icon: Icons.request_quote,
        value: () async => const DashletValue(null),
        route: '/home/accounting/aged_receivables',
        valueBuilder: (_, _) => const HMBEmpty(),
      ),
      DashletCard<void>.route(
        label: 'Statements',
        hint: 'Show customer statement balances and activity',
        icon: Icons.description,
        value: () async => const DashletValue(null),
        route: '/home/accounting/statements',
        valueBuilder: (_, _) => const HMBEmpty(),
      ),
      DashletCard<void>.route(
        label: 'Job Profit',
        hint: 'Show income, costs and profit for a job',
        icon: Icons.trending_up,
        value: () async => const DashletValue(null),
        route: '/home/accounting/job_profit',
        valueBuilder: (_, _) => const HMBEmpty(),
      ),
    ],
  );
}

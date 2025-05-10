// lib/src/ui/dashboard/billing_dashlet.dart
import 'package:flutter/material.dart';

import '../dashlet_card.dart';

/// Dashlet for Billing sub-dashboard
class AccountingDashlet extends StatelessWidget {
  const AccountingDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<void>(
    label: 'Accounting',
    icon: Icons.account_balance_wallet,
    dashletValue: () => Future.value(const DashletValue(null)),
    route: '/dashboard/accounting',
    widgetBuilder: (_, _) => const SizedBox.shrink(),
  );
}

// lib/src/ui/dashboard/billing_dashlet.dart
import 'package:flutter/material.dart';

import '../dashlet_card.dart';

/// Dashlet for Billing sub-dashboard
class BillingDashlet extends StatelessWidget {
  const BillingDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<void>(
    label: 'Billing',
    icon: Icons.account_balance_wallet,
    dashletValue: () => Future.value(const DashletValue(null)),
    route: '/dashboard/billing',
    widgetBuilder: (_, _) => const SizedBox.shrink(),
  );
}

/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/ui/dashboard/billing_dashlet.dart
import 'package:flutter/material.dart';

import '../../dashlet_card.dart';

/// Dashlet for Billing sub-dashboard
class AccountingDashlet extends StatelessWidget {
  const AccountingDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<void>.route(
    label: 'Accounting',
    hint: 'Create Estimates, Quotes and Invoices and scan Receipts',
    icon: Icons.account_balance_wallet,
    value: () => Future.value(const DashletValue(null)),
    route: '/home/accounting',
  );
}

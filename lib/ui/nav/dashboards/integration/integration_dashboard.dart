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

// lib/src/ui/dashboard/settings_dashboard_page.dart
import 'package:flutter/material.dart';

import '../../nav.g.dart';

class IntegrationDashboardPage extends StatelessWidget {
  const IntegrationDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => DashboardPage(
    title: 'Integrations',
    dashlets: [
      DashletCard<void>.route(
        label: 'Xero',
        hint: 'Configure integration with Xero to upload Invoices',
        icon: Icons.extension,
        value: () => Future.value(const DashletValue(null)),
        route: '/home/settings/integrations/xero',
      ),
    ],
  );
}

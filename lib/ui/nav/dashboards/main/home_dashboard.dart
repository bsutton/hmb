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

// lib/src/ui/dashboard/main_dashboard_page.dart
import 'package:flutter/material.dart';

import '../dashboard.dart';
import 'dashlets/dashlets.g.dart';

class MainDashboardPage extends StatelessWidget {
  const MainDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: DashboardPage(
      title: 'Dashboard',
      dashlets: [
        JobsDashlet(),
        HelpDashlet(),
        NextJobDashlet(),
        ToDoDashlet(),
        ShoppingDashlet(),
        PackingDashlet(),
        AccountingDashlet(),
        CustomersDashlet(),
        SuppliersDashlet(),
        ToolsDashlet(),
        ManufacturersDashlet(),
        BackupDashlet(),
        SettingsDashlet(),
      ],
    ),
  );
}

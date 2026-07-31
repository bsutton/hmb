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
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../../../../dao/dao.g.dart';
import '../dashboard.dart';
import 'dashlets/dashlets.g.dart';
import 'dashlets/today.dart';

class MainDashboardPage extends StatelessWidget {
  const MainDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
    future: _showBookingRequests(),
    builder: (context, showBookingRequests) => Scaffold(
      body: DashboardPage(
        title: 'Dashboard',
        dashlets: [
          const JobsDashlet(),
          const TodayDashlet(),
          if (showBookingRequests ?? false) const BookingRequestsDashlet(),
          const HelpDashlet(),
          const NextJobDashlet(),
          const ToDoDashlet(),
          const ShoppingDashlet(),
          const PackingDashlet(),
          const AccountingDashlet(),
          const CustomersDashlet(),
          const SuppliersDashlet(),
          const ToolsDashlet(),
          const ManufacturersDashlet(),
          const BackupDashlet(),
          const SettingsDashlet(),
        ],
      ),
    ),
  );

  Future<bool> _showBookingRequests() async {
    final daoSystem = DaoSystem();
    final system = await daoSystem.get();
    if (!system.enableIhserverIntegration ||
        Strings.isBlank(system.ihserverUrl)) {
      return false;
    }
    final credentials = await daoSystem.getIhserverCredentials();
    return Strings.isNotBlank(credentials.token);
  }
}

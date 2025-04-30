// lib/src/ui/dashboard/main_dashboard_page.dart
import 'package:flutter/material.dart';

import 'dashlets/dashlets.g.dart';
import 'dashlets/google_backup.dart';
import 'nav.g.dart';

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
        ShoppingDashlet(),
        PackingDashlet(),
        BillingDashlet(),
        CustomersDashlet(),
        SuppliersDashlet(),
        ToolsDashlet(),
        ManufacturersDashlet(),
        GoogleBackupDashlset(),
        SettingsDashlet(),
      ],
    ),
  );
}

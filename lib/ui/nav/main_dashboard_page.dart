// lib/src/ui/dashboard/main_dashboard_page.dart
import 'package:flutter/material.dart';

import '../../util/util.g.dart';
import 'dashlets/dashlets.g.dart';
import 'dashlets/google_backup.dart';
import 'nav.g.dart';

class MainDashboardPage extends StatefulWidget {
  const MainDashboardPage({super.key});

  @override
  State<MainDashboardPage> createState() => _MainDashboardPageState();
}

class _MainDashboardPageState extends State<MainDashboardPage> with RouteAware {
  @override
  void initState() {
    super.initState();
    setAppTitle('Dashboard');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    setState(() {});
    setAppTitle('Dashboard');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        children: const [
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
    ),
  );
}

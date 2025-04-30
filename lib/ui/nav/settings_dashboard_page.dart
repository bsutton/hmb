// lib/src/ui/dashboard/settings_dashboard_page.dart
import 'package:flutter/material.dart';

import 'dashlets/google_backup.dart';
import 'nav.g.dart';

class SettingsDashboardPage extends StatelessWidget {
  const SettingsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          DashletCard<void>(
            label: 'SMS Templates',
            icon: Icons.message,
            future: Future.value(const DashletValue(null)),
            route: '/system/sms_templates',
            widgetBuilder: (_, _) => const SizedBox.shrink(),
          ),
          DashletCard<void>(
            label: 'Business',
            icon: Icons.business,
            future: Future.value(const DashletValue(null)),
            route: '/system/business',
            widgetBuilder: (_, _) => const SizedBox.shrink(),
          ),
          DashletCard<void>(
            label: 'Billing',
            icon: Icons.account_balance,
            future: Future.value(const DashletValue(null)),
            route: '/system/billing',
            widgetBuilder: (_, _) => const SizedBox.shrink(),
          ),
          DashletCard<void>(
            label: 'Contact',
            icon: Icons.contact_phone,
            future: Future.value(const DashletValue(null)),
            route: '/system/contact',
            widgetBuilder: (_, _) => const SizedBox.shrink(),
          ),
          DashletCard<void>(
            label: 'Integration',
            icon: Icons.extension,
            future: Future.value(const DashletValue(null)),
            route: '/system/integration',
            widgetBuilder: (_, _) => const SizedBox.shrink(),
          ),
          DashletCard<void>(
            label: 'Setup Wizard',
            icon: Icons.auto_fix_high,
            future: Future.value(const DashletValue(null)),
            route: '/system/wizard',
            widgetBuilder: (_, _) => const SizedBox.shrink(),
          ),
          
          DashletCard<void>(
            label: 'Backup Local',
            icon: Icons.save,
            future: Future.value(const DashletValue(null)),
            route: '/system/backup/local',
            widgetBuilder: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}

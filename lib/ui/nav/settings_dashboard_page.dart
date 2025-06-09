// lib/src/ui/dashboard/settings_dashboard_page.dart
import 'package:flutter/material.dart';

import 'nav.g.dart';

class SettingsDashboardPage extends StatelessWidget {
  const SettingsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => DashboardPage(
    title: 'Settings',
    dashlets: [
      DashletCard<void>(
        label: 'SMS Templates',
        icon: Icons.message,
        dashletValue: () => Future.value(const DashletValue(null)),
        route: '/system/sms_templates',
        widgetBuilder: (_, _) => const SizedBox.shrink(),
      ),
      DashletCard<void>(
        label: 'Business',
        icon: Icons.business,
        dashletValue: () => Future.value(const DashletValue(null)),
        route: '/system/business',
        widgetBuilder: (_, _) => const SizedBox.shrink(),
      ),
      DashletCard<void>(
        label: 'Billing',
        icon: Icons.account_balance,
        dashletValue: () => Future.value(const DashletValue(null)),
        route: '/system/billing',
        widgetBuilder: (_, _) => const SizedBox.shrink(),
      ),
      DashletCard<void>(
        label: 'Contact',
        icon: Icons.contact_phone,
        dashletValue: () => Future.value(const DashletValue(null)),
        route: '/system/contact',
        widgetBuilder: (_, _) => const SizedBox.shrink(),
      ),
      DashletCard<void>(
        label: 'Integration',
        icon: Icons.extension,
        dashletValue: () => Future.value(const DashletValue(null)),
        route: '/system/integration',
        widgetBuilder: (_, _) => const SizedBox.shrink(),
      ),
      DashletCard<void>(
        label: 'Setup Wizard',
        icon: Icons.auto_fix_high,
        dashletValue: () => Future.value(const DashletValue(null)),
        route: '/system/wizard',
        widgetBuilder: (_, _) => const SizedBox.shrink(),
      ),

      DashletCard<void>(
        label: 'Backup Local',
        icon: Icons.save,
        dashletValue: () => Future.value(const DashletValue(null)),
        route: '/system/backup/local',
        widgetBuilder: (_, _) => const SizedBox.shrink(),
      ),
    ],
  );
}

// lib/src/ui/dashboard/settings_dashlet.dart
import 'package:flutter/material.dart';

import '../dashlet_card.dart';

/// Dashlet for Settings sub-dashboard
class SettingsDashlet extends StatelessWidget {
  const SettingsDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<void>(
    label: 'Settings',
    icon: Icons.settings,
    future: Future.value(const DashletValue(null)),
    route: '/dashboard/settings',
    widgetBuilder: (_, _) => const SizedBox.shrink(),
  );
}

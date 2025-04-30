// lib/src/ui/dashboard/help_dashlet.dart
import 'package:flutter/material.dart';

import '../dashlet_card.dart';

/// Dashlet for Help sub-dashboard
class HelpDashlet extends StatelessWidget {
  const HelpDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<void>(
    label: 'Help',
    icon: Icons.help,
    dashletValue: () => Future.value(const DashletValue(null)),
    route: '/dashboard/help',
    widgetBuilder: (_, _) => const SizedBox.shrink(),
  );
}

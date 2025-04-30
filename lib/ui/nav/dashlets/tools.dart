// lib/src/ui/dashboard/tools_dashlet.dart
import 'package:flutter/material.dart';

import '../dashlet_card.dart';

/// Dashlet for Tools shortcut
class ToolsDashlet extends StatelessWidget {
  const ToolsDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<void>(
    label: 'Tools',
    icon: Icons.build,
    dashletValue: () => Future.value(const DashletValue(null)),
    route: '/extras/tools',
    widgetBuilder: (_, _) => const SizedBox.shrink(),
  );
}

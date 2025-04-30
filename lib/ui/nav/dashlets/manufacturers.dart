// lib/src/ui/dashboard/manufacturers_dashlet.dart
import 'package:flutter/material.dart';

import '../dashlet_card.dart';

/// Dashlet for Manufacturers shortcut
class ManufacturersDashlet extends StatelessWidget {
  const ManufacturersDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<void>(
    label: 'Manufacturers',
    icon: Icons.factory,
    future: Future.value(const DashletValue(null)),
    route: '/extras/manufacturers',
    widgetBuilder: (_, _) => const SizedBox.shrink(),
  );
}

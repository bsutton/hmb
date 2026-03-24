/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'package:flutter/material.dart';

import '../../../../dao/dao.g.dart';
import '../dashboard.dart';
import '../dashlet_card.dart';

class ToolsDashboardPage extends StatelessWidget {
  const ToolsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => DashboardPage(
    title: 'Tools',
    dashlets: [
      DashletCard<int>.route(
        label: 'Inventory',
        hint: 'Maintain a list of tools, warranty details and receipts',
        icon: Icons.build,
        value: () async => DashletValue((await DaoTool().getAllTools()).length),
        route: '/home/tools/inventory',
      ),
      DashletCard<int>.route(
        label: 'Plasterboard',
        hint: 'Create room projects, edit room outlines, and sheet layouts',
        icon: Icons.grid_view,
        value: () async => DashletValue(
          (await DaoPlasterProject().getByFilter(null)).length,
        ),
        route: '/home/tools/plasterboard',
      ),
    ],
  );
}

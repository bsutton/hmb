import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../dashlet_card.dart';

/// Dashlet for pending packing items count
class PackingDashlet extends StatelessWidget {
  const PackingDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<int>(
    label: 'Packing',
    icon: Icons.inventory_2,
    dashletValue: getPackingItems,
    route: '/packing',
  );

  Future<DashletValue<int>> getPackingItems() async {
    final items = await DaoTaskItem().getPackingItems();

    final count = items.where((it) => !it.completed).length;
    return DashletValue(count);
  }
}

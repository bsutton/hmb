// lib/src/ui/dashboard/shopping_dashlet.dart
import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../dashlet_card.dart';

/// Dashlet for pending shopping items count
class ShoppingDashlet extends StatelessWidget {
  const ShoppingDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<int>(
    label: 'Shopping',
    icon: Icons.shopping_cart,
    future: DaoTaskItem().getShoppingItems().then((items) {
      final count = items.where((it) => !it.completed).length;
      return DashletValue(count);
    }),
    route: '/shopping',
  );
}

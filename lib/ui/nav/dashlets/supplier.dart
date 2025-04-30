// lib/src/ui/dashboard/suppliers_dashlet.dart
import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../dashlet_card.dart';

/// Dashlet for total suppliers count
class SuppliersDashlet extends StatelessWidget {
  const SuppliersDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<int>(
    label: 'Suppliers',
    icon: Icons.store,
    dashletValue: getSupplierCount,
    route: '/suppliers',
  );

  Future<DashletValue<int>> getSupplierCount() async {
    final count = await DaoSupplier().count();
    return DashletValue(count);
  }
}

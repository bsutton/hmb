// lib/src/ui/dashboard/customers_dashlet.dart
import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../dashlet_card.dart';

/// Dashlet for total customers count
class CustomersDashlet extends StatelessWidget {
  const CustomersDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<int>(
    label: 'Customers',
    icon: Icons.people,
    future: getCustomerCount(),
    route: '/customers',
  );

  Future<DashletValue<int>> getCustomerCount() async {
    final count = await DaoCustomer().count();
    return DashletValue(count);
  }
}

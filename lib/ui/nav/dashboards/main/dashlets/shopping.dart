/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/ui/dashboard/shopping_dashlet.dart
import 'package:flutter/material.dart';

import '../../../../../dao/dao.g.dart';
import '../../dashlet_card.dart';

/// Dashlet for pending shopping items count
class ShoppingDashlet extends StatelessWidget {
  const ShoppingDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<int>.route(
    label: 'Shopping',
    hint: 'Maintain a list of items to be purchased for each Job',
    icon: Icons.shopping_cart,
    value: getShopping,
    route: '/home/shopping',
  );

  Future<DashletValue<int>> getShopping() async {
    final items = await DaoTaskItem().getShoppingItems();
    final count = items.where((it) => !it.completed).length;
    return DashletValue(count);
  }
}

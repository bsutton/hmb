/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../../../../../dao/dao.g.dart';
import '../../../dashlet_card.dart';

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

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
import '../../dashlet_card.dart';

/// Dashlet for pending packing items count
class PackingDashlet extends StatelessWidget {
  const PackingDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<int>.route(
    label: 'Packing',
    hint: 'Create a packing list for specific Jobs',
    icon: Icons.inventory_2,
    value: getPackingItems,
    route: '/home/packing',
  );

  Future<DashletValue<int>> getPackingItems() async {
    final items = await DaoTaskItem().getPackingItems(
      showPreScheduledJobs: false,
      showPreApprovedTask: false,
    );

    final count = items.where((it) => !it.completed).length;
    return DashletValue(count);
  }
}

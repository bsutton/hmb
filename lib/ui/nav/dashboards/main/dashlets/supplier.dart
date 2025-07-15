/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/ui/dashboard/suppliers_dashlet.dart
import 'package:flutter/material.dart';

import '../../../../../dao/dao.g.dart';
import '../../dashlet_card.dart';

/// Dashlet for total suppliers count
class SuppliersDashlet extends StatelessWidget {
  const SuppliersDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<int>.route(
    label: 'Suppliers',
    hint: 'Maintain a list of Suppliers, for Tools and Trades',
    icon: Icons.add_card,
    value: getSupplierCount,
    route: '/home/suppliers',
  );

  Future<DashletValue<int>> getSupplierCount() async {
    final count = await DaoSupplier().count();
    return DashletValue(count);
  }
}

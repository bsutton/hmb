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

// lib/src/ui/dashboard/customers_dashlet.dart
import 'package:flutter/material.dart';

import '../../../../../dao/dao.g.dart';
import '../../dashlet_card.dart';

/// Dashlet for total customers count
class CustomersDashlet extends StatelessWidget {
  const CustomersDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<int>.route(
    label: 'Customers',
    hint: 'Maintain your list of customers',
    icon: Icons.people,
    value: getCustomerCount,
    route: '/home/customers',
  );

  Future<DashletValue<int>> getCustomerCount() async {
    final count = await DaoCustomer().count();
    return DashletValue(count);
  }
}

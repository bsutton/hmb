/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

/// Dashlet for active jobs count
library;

import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../../../util/util.g.dart';
import '../dashlet_card.dart';

class InvoiceDashlet extends StatelessWidget {
  const InvoiceDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<String>(
    label: 'Invoices',
    icon: Icons.receipt_long,
    dashletValue: getInvoicedThisMonth,
    route: '/accounting/invoices',
  );

  Future<DashletValue<String>> getInvoicedThisMonth() async {
    final invoices = await DaoInvoice().getAll();
    final now = DateTime.now();
    var total = MoneyEx.zero;
    for (final inv in invoices) {
      if (inv.sent &&
          inv.createdDate.year == now.year &&
          inv.createdDate.month == now.month) {
        total += inv.totalAmount;
      }
    }
    return DashletValue('mtd: ${total.format('S#')}');
  }
}

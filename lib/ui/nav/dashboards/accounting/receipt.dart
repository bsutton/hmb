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

/// Dashlet for active jobs count
library;

import 'package:flutter/material.dart';

import '../../../../dao/dao.g.dart';
import '../../../../util/util.g.dart';
import '../dashlet_card.dart';

class ReceiptDashlet extends StatelessWidget {
  const ReceiptDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<String>.route(
    label: 'Receipts',
    hint: 'Track and Scan receipts',
    icon: Icons.receipt,
    value: getReceiptsThisMonth,
    route: '/home/accounting/receipts',
  );

  Future<DashletValue<String>> getReceiptsThisMonth() async {
    final now = DateTime.now();
    final receipts = await DaoReceipt().getByFilter(
      dateFrom: DateTime(now.year, now.month),
      dateTo: DateTime(now.year, now.month + 1, 0),
    );
    var total = MoneyEx.zero;
    for (final r in receipts) {
      total += r.totalIncludingTax;
    }
    return DashletValue('mtd: ${total.format('S#')}');
  }
}

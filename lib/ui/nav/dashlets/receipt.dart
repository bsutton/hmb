/// Dashlet for active jobs count
library;

import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../../../util/util.g.dart';
import '../dashlet_card.dart';

class ReceiptDashlet extends StatelessWidget {
  const ReceiptDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<String>(
    label: 'Receipts',
    icon: Icons.receipt,
    dashletValue: getReceiptsThisMonth,
    route: '/accounting/receipts',
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
    return DashletValue('MTD: ${total.format('S#')}');
  }
}

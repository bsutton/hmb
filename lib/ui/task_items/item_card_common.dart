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

import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../entity/task_item.dart';
import '../../util/dart/fixed_ex.dart';
import '../widgets/layout/layout.g.dart';
import 'list_shopping_screen.dart';

class ItemCardCommon extends StatelessWidget {
  final CustomerAndJob customerAndJob;
  final TaskItem taskItem;

  const ItemCardCommon({
    required this.customerAndJob,
    required this.taskItem,
    super.key,
  });

  @override
  Widget build(BuildContext context) => HMBColumn(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 2,
    children: [
      _line(customerAndJob.customer.name),
      _line('Job: ${customerAndJob.job.summary}'),
      _line('Task: ${customerAndJob.task.name}'),
      if (Strings.isNotBlank(customerAndJob.supplier?.name))
        _line('Supplier: ${customerAndJob.supplier!.name}'),
      if (Strings.isNotBlank(taskItem.purpose))
        _line('Note: ${taskItem.purpose}'),
      _line(_quantityLabel),
      _line(_costLabel),
      if (_totalLabel case final totalLabel?) _line(totalLabel),
    ],
  );

  String get _quantityLabel {
    final price = taskItem.actualPrice ?? taskItem.estimatedPrice;
    if (price == null) {
      return 'Quantity: —';
    }
    return price.isPackagePrice
        ? 'Packages: ${price.quantity.toInt()} '
              '(${price.totalItemQuantity.toInt()} items)'
        : 'Quantity: ${price.quantity.compact()}';
  }

  String get _costLabel {
    final price = taskItem.actualPrice ?? taskItem.estimatedPrice;
    if (price == null) {
      return 'Cost: —';
    }
    return price.isPackagePrice
        ? 'Cost per package: ${price.unitCost}'
        : 'Cost per item: ${price.unitCost}';
  }

  String? get _totalLabel {
    final price = taskItem.actualPrice ?? taskItem.estimatedPrice;
    return price == null ? null : 'Total: ${price.totalCost}';
  }

  Widget _line(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      softWrap: false,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

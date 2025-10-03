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

// ignore_for_file: discarded_futures

import 'package:flutter/material.dart';

import '../../entity/task_item.dart';
import '../../util/dart/money_ex.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/text/hmb_text_themes.dart';
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
    children: [
      HMBTextLine(customerAndJob.customer.name),
      HMBTextLine('Job: ${customerAndJob.job.summary}'),
      HMBTextLine('Task: ${customerAndJob.task.name}'),
      HMBTextLine('Supplier: ${customerAndJob.supplier?.name ?? ''}'),
      HMBTextLine(
        '''Qty: ${taskItem.actualMaterialQuantity ?? taskItem.estimatedMaterialQuantity ?? MoneyEx.zero}''',
      ),
      HMBTextLine(
        '''Unit Cost: ${taskItem.actualMaterialUnitCost ?? taskItem.estimatedMaterialUnitCost ?? MoneyEx.zero}''',
      ),
    ],
  );
}

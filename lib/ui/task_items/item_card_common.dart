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
      _line(customerAndJob.customer.name),
      _line('Job: ${customerAndJob.job.summary}'),
      _line('Task: ${customerAndJob.task.name}'),
      if (Strings.isNotBlank(customerAndJob.supplier?.name))
        _line('Supplier: ${customerAndJob.supplier!.name}'),
      if (Strings.isNotBlank(taskItem.purpose))
        _line('Note: ${taskItem.purpose}'),
      _line(
        '''Qty: ${taskItem.actualMaterialQuantity ?? taskItem.estimatedMaterialQuantity ?? MoneyEx.zero}''',
      ),
      _line(
        '''Unit Cost: ${taskItem.actualMaterialUnitCost ?? taskItem.estimatedMaterialUnitCost ?? MoneyEx.zero}''',
      ),
    ],
  );

  Widget _line(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      softWrap: true,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

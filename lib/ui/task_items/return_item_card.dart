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

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../widgets/hmb_delete_icon.dart';
import '../widgets/widgets.g.dart';
import 'list_packing_screen.dart';
import 'list_shopping_screen.dart';
import 'shopping_item_card.dart';

/// “Returns” mode: undo/delete return, only if allowed.
class ReturnItemCard extends ShoppingItemCard {
  const ReturnItemCard({
    required super.itemContext,
    required super.onReload,
    super.key,
  });

  @override
  Widget buildActions(BuildContext context, CustomerAndJob det) {
    final ti = itemContext.taskItem;
    final itemType = ti.itemType;
    final canReturn =
        (itemType == TaskItemType.materialsBuy ||
            itemType == TaskItemType.toolsBuy ||
            itemType == TaskItemType.consumablesBuy) &&
        !itemContext.wasReturned;

    return HMBDeleteIcon(
      enabled: canReturn,
      onPressed: () async {
        await _delete(itemContext, context);
        await onReload();
      },
      hint: 'Delete Item',
    );
  }

  Future<void> _delete(
    TaskItemContext itemContext,
    BuildContext context,
  ) async {
    final taskItem = itemContext.taskItem;

    if (taskItem.billed) {
      HMBToast.error("You can't delete an return that has been invoiced.");
      return;
    }

    await DaoTaskItem().delete(taskItem.id);
  }
}

// ignore_for_file: discarded_futures

import 'package:flutter/material.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../widgets/widgets.g.dart';
import 'list_packing_screen.dart';
import 'list_shopping_screen.dart';
import 'shopping_item_card.dart';

/// “Returns” mode: undo/delete return, only if allowed.
class ReturnItemCard extends ShoppingItemCard {
  const ReturnItemCard({
    required super.itemContext,
    required this.onReload,
    super.key,
  });

  final Future<void> Function() onReload;

  @override
  Widget buildActions(
    BuildContext context,
    CustomerAndJob det,
    TaskItem taskItem,
  ) {
    final ti = itemContext.taskItem;
    final itemType = TaskItemTypeEnum.fromId(ti.itemTypeId);
    final canReturn =
        (itemType == TaskItemTypeEnum.materialsBuy ||
            itemType == TaskItemTypeEnum.toolsBuy) &&
        !itemContext.wasReturned;

    return IconButton(
      icon: Icon(Icons.delete, color: canReturn ? Colors.red : Colors.grey),
      onPressed:
          canReturn
              ? () async {
                await _delete(itemContext, context);
                await onReload();
              }
              : null,
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

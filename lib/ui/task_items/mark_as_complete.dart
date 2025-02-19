import 'package:fixed/fixed.dart';
import 'package:flutter/material.dart';

import '../../dao/dao.g.dart';
import '../../entity/task_item.dart';
import '../../entity/task_item_type.dart';
import '../../util/util.g.dart';
import '../crud/tool/tool.g.dart';
import '../widgets/fields/fields.g.dart';
import '../widgets/widgets.g.dart';
import 'task_items.g.dart';

Future<void> markAsCompleted(
  TaskItemContext itemContext,
  BuildContext context,
) async {
  final costController = TextEditingController();
  final quantityController = TextEditingController();

  final taskItem = itemContext.taskItem;

  final itemType = TaskItemTypeEnum.fromId(taskItem.itemTypeId);

  /// TODO: need to rework this as part of allowing  a T&M job
  /// to invoice a Fixed priced task.
  switch (itemType) {
    case TaskItemTypeEnum.materialsBuy:
    case TaskItemTypeEnum.materialsStock:
    case TaskItemTypeEnum.toolsBuy:
    case TaskItemTypeEnum.toolsOwn:
      costController.text =
          itemContext.taskItem.estimatedMaterialUnitCost.toString();
      quantityController.text =
          itemContext.taskItem.estimatedMaterialQuantity.toString();
    case TaskItemTypeEnum.labour:
      if (taskItem.labourEntryMode == LabourEntryMode.hours) {
        costController.text =
            itemContext.taskItem.estimatedLabourCost.toString();
        quantityController.text = '1.00';
      } else {
        costController.text =
            itemContext.taskItem.estimatedLabourCost.toString();
        quantityController.text = '1.00';
      }
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Complete Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HMBTextField(
                controller: costController,
                labelText: 'Cost per item (optional)',
                keyboardType: TextInputType.number,
              ),
              HMBTextField(
                controller: quantityController,
                labelText: 'Quantity (optional)',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            HMBButton(
              onPressed: () => Navigator.of(context).pop(false),
              label: 'Cancel',
            ),
            HMBButton(
              onPressed: () => Navigator.of(context).pop(true),
              label: 'Complete',
            ),
          ],
        ),
  );

  if (confirmed ?? false) {
    final quantity = Fixed.tryParse(quantityController.text) ?? Fixed.one;
    final unitCost = MoneyEx.tryParse(costController.text);

    await DaoTaskItem().markAsCompleted(
      itemContext.billingType,
      itemContext.taskItem,
      unitCost,
      quantity,
    );

    // Check if item type is "Tool - buy" and prompt to add to tool list
    if (itemContext.taskItem.itemTypeId ==
        (await DaoTaskItemType().getToolsBuy()).id) {
      if (context.mounted) {
        final addTool = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Add Tool to Tool List?'),
                content: const Text(
                  'Would you like to add this tool to your tool list?',
                ),
                actions: [
                  HMBButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    label: 'No',
                  ),
                  HMBButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    label: 'Yes',
                  ),
                ],
              ),
        );

        if ((addTool ?? false) && context.mounted) {
          await ToolStockTakeWizard.start(
            context: context,
            onFinish: (reason) async {
              Navigator.of(context).pop();
            },
            cost: unitCost,
            name: itemContext.taskItem.description,
            offerAnother: false,
          );
        }
      }
    }
  }
}

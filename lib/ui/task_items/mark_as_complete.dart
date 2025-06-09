import 'package:fixed/fixed.dart';
import 'package:flutter/material.dart' hide StatefulBuilder;

import '../../dao/dao.g.dart';
import '../../entity/supplier.dart';
import '../../entity/task_item.dart';
import '../../entity/task_item_type.dart';
import '../../util/util.g.dart';
import '../crud/tool/tool.g.dart';
import '../widgets/fields/fields.g.dart';
import '../widgets/select/hmb_droplist.dart';
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

  // TODO(bsutton): need to rework this as part of allowing  a T&M job
  /// to invoice a Fixed priced task.
  switch (itemType) {
    case TaskItemTypeEnum.materialsBuy:
    case TaskItemTypeEnum.materialsStock:
    case TaskItemTypeEnum.toolsBuy:
    case TaskItemTypeEnum.toolsOwn:
      costController.text = taskItem.estimatedMaterialUnitCost.toString();
      quantityController.text = taskItem.estimatedMaterialQuantity.toString();
    case TaskItemTypeEnum.labour:
      if (taskItem.labourEntryMode == LabourEntryMode.hours) {
        costController.text = itemContext.taskItem.estimatedLabourHours
            .toString();
        quantityController.text = '1.00';
      } else {
        costController.text = itemContext.taskItem.estimatedLabourCost
            .toString();
        quantityController.text = '1.00';
      }
  }

  // Load current supplier
  Supplier? selectedSupplier;
  if (taskItem.supplierId != null) {
    selectedSupplier = await DaoSupplier().getById(taskItem.supplierId);
  }

  if (!context.mounted) {
    return;
  }
  final confirmed = await showDialog<bool>(
    // ignore: use_build_context_synchronously
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: const Text('Complete Item'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Full, wrapping description
              Text(
                taskItem.description,
                style: Theme.of(context).textTheme.titleMedium,
                softWrap: true,
              ),

              // Optional dimensions line
              if (taskItem.hasDimensions) ...[
                const SizedBox(height: 8),
                Text(
                  taskItem.dimensions,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],

              const SizedBox(height: 16),

              // Supplier droplist
              HMBDroplist<Supplier>(
                title: 'Supplier',
                items: (filter) => DaoSupplier().getByFilter(filter),
                format: (sup) => sup.name,
                selectedItem: () async => selectedSupplier,
                required: false,
                onChanged: (sup) {
                  setStateDialog(() {
                    selectedSupplier = sup;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Cost per item field
              HMBTextField(
                controller: costController,
                labelText: 'Cost per item (optional)',
                keyboardType: TextInputType.number,
              ),

              // Quantity field
              HMBTextField(
                controller: quantityController,
                labelText: 'Quantity (optional)',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
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
    ),
  );

  if (confirmed ?? false) {
    final quantity = Fixed.tryParse(quantityController.text) ?? Fixed.one;
    final unitCost = MoneyEx.tryParse(costController.text);

    // Mark as completed (sets actual cost/qty and charge)
    await DaoTaskItem().markAsCompleted(
      itemContext.billingType,
      taskItem,
      unitCost,
      quantity,
    );

    // Persist supplier change if any
    if (selectedSupplier?.id != null) {
      taskItem.supplierId = selectedSupplier!.id;
      await DaoTaskItem().update(taskItem);
    }

    // If it's a "Tools - buy" item, prompt to add to the tool list
    if (taskItem.itemTypeId == (await DaoTaskItemType().getToolsBuy()).id) {
      if (context.mounted) {
        final addTool = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
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
            name: taskItem.description,
            offerAnother: false,
          );
        }
      }
    }
  }
}

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

import 'package:fixed/fixed.dart';
import 'package:flutter/material.dart' hide StatefulBuilder;
import 'package:strings/strings.dart';

import '../../dao/dao.g.dart';
import '../../entity/job.dart';
import '../../entity/supplier.dart';
import '../../entity/task_item.dart';
import '../../entity/task_item_type.dart';
import '../../util/flutter/flutter_util.g.dart';
import '../crud/tool/tool.g.dart';
import '../widgets/fields/fields.g.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/widgets.g.dart';
import 'task_items.g.dart';

Future<void> markAsCompleted(
  TaskItemContext itemContext,
  BuildContext context,
) async {
  final costController = TextEditingController();
  final quantityController = TextEditingController();
  final packetSizeController = TextEditingController(text: '1');
  final taskItem = itemContext.taskItem;
  final itemType = taskItem.itemType;

  switch (itemType) {
    case TaskItemType.materialsBuy:
    case TaskItemType.materialsStock:
    case TaskItemType.toolsOwn:
    case TaskItemType.toolsBuy:
    case TaskItemType.consumablesStock:
    case TaskItemType.consumablesBuy:
      costController.text =
          (taskItem.actualMaterialUnitCost ??
                  taskItem.estimatedMaterialUnitCost)
              .toString();
      quantityController.text =
          (taskItem.actualMaterialQuantity ??
                  taskItem.estimatedMaterialQuantity)
              .toString();
    case TaskItemType.labour:
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
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: const Text('Complete Item'),
        content: SingleChildScrollView(
          child: HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Full, wrapping description
              Text(
                taskItem.description,
                style: Theme.of(context).textTheme.titleMedium,
                softWrap: true,
              ),
              if (Strings.isNotBlank(taskItem.purpose))
                Text(
                  taskItem.purpose,
                  style: Theme.of(context).textTheme.titleMedium,
                  softWrap: true,
                ),

              // Optional dimensions line
              if (taskItem.hasDimensions) ...[
                Text(
                  taskItem.dimensions,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],

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

              // Cost per item field
              HMBTextField(
                controller: costController,
                labelText: 'Cost per packet',
                keyboardType: TextInputType.number,
              ),

              HMBTextField(
                controller: packetSizeController,
                labelText: 'Items per packet',
                keyboardType: TextInputType.number,
              ),

              // Quantity field
              HMBTextField(
                controller: quantityController,
                labelText: 'Packets purchased',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          HMBButton(
            onPressed: () => Navigator.of(context).pop(false),
            label: 'Cancel',
            hint: "Don't mark the item as complete",
          ),
          HMBButton(
            onPressed: () => Navigator.of(context).pop(true),
            hint:
                '''Mark the Item as complete. Completed Items will appear on T&M Invoices''',
            label: 'Complete',
          ),
        ],
      ),
    ),
  );

  if (confirmed ?? false) {
    final packetsPurchased =
        Fixed.tryParse(quantityController.text) ?? Fixed.one;
    final packetSize = FixedEx.tryParseOrElse(
      packetSizeController.text,
      Fixed.one,
    );
    final safePacketSize = packetSize.isZero ? Fixed.one : packetSize;
    final packetCost = MoneyEx.tryParse(costController.text);
    final quantity = packetsPurchased * safePacketSize;
    final unitCost = packetCost.divideByFixed(safePacketSize);

    // For fixed-price tasks, actuals are captured for P&L but should not
    // force user-defined billing charges.
    if (itemType == TaskItemType.labour) {
      final updated = taskItem.copyWith(completed: true);
      await DaoTaskItem().update(updated);
      taskItem.completed = true;
    } else if (itemContext.billingType == BillingType.fixedPrice) {
      final updated = taskItem.copyWith(
        completed: true,
        actualMaterialUnitCost: unitCost,
        actualMaterialQuantity: quantity,
      );
      await DaoTaskItem().update(updated);
      taskItem
        ..completed = true
        ..actualMaterialUnitCost = unitCost
        ..actualMaterialQuantity = quantity;
    } else {
      await DaoTaskItem().markAsCompleted(
        item: taskItem,
        materialUnitCost: unitCost,
        materialQuantity: quantity,
      );
    }

    // Persist supplier change if any
    if (selectedSupplier?.id != null) {
      taskItem.supplierId = selectedSupplier!.id;
      await DaoTaskItem().update(taskItem);
    }

    // If it's a "Tools - buy" item, prompt to add to the tool list
    if (taskItem.itemType == TaskItemType.toolsBuy ||
        taskItem.itemType == TaskItemType.consumablesBuy) {
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
                hint: "Don't add the tool to your tool inventory",
              ),
              HMBButton(
                onPressed: () => Navigator.of(context).pop(true),
                label: 'Yes',
                hint:
                    '''Add the tool to you tool your tool inventory and optionally capture the receipt, serial number and a photo.''',
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

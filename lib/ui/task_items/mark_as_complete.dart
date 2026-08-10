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

import 'dart:async';

import 'package:flutter/material.dart' hide StatefulBuilder;
import 'package:strings/strings.dart';

import '../../dao/dao.g.dart';
import '../../entity/supplier.dart';
import '../../entity/task_item_type.dart';
import '../crud/tool/tool.g.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/widgets.g.dart';
import 'task_items.g.dart';

Future<void> markAsCompleted(
  TaskItemContext itemContext,
  BuildContext context,
) async {
  final taskItem = itemContext.taskItem;
  final itemType = taskItem.itemType;
  final isLabour = itemType == TaskItemType.labour;
  final priceController = MaterialPriceEditingController(
    price: taskItem.actualPrice ?? taskItem.estimatedPrice,
  );

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

              if (!isLabour) ...[
                HMBDroplist<Supplier>(
                  title: 'Supplier',
                  items: (filter) => DaoSupplier().getByFilter(filter),
                  format: (sup) => sup.name,
                  selectedItem: () async => selectedSupplier,
                  required: false,
                  onChanged: (sup) {
                    unawaited(DaoSupplier().recordAccess(sup?.id));
                    setStateDialog(() {
                      selectedSupplier = sup;
                    });
                  },
                ),
                MaterialPriceEditor(
                  controller: priceController,
                  title: 'Actual pricing',
                ),
              ],
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
    if (isLabour) {
      taskItem.completed = true;
      await DaoTaskItem().update(taskItem);
    } else {
      final price = priceController.value;
      if (price == null) {
        priceController.dispose();
        return;
      }
      await DaoTaskItem().markAsCompleted(item: taskItem, price: price);

      taskItem.supplierId = selectedSupplier?.id;
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
            cost: priceController.value!.equivalentItemCost,
            name: taskItem.description,
            offerAnother: false,
          );
        }
      }
    }
  }
  priceController.dispose();
}

// lib/ui/screens/shopping_item_card.dart

import 'package:flutter/material.dart';

import '../../dao/dao_supplier.dart';
import '../../dao/dao_task_item.dart';
import '../../entity/supplier.dart';
import '../../util/fixed_ex.dart';
import '../../util/money_ex.dart';
import '../widgets/fields/fields.g.dart';
import '../widgets/select/hmb_droplist.dart';
import 'task_items.g.dart';

/// Opens a dialog to view/edit a single shopping item's details.
/// Opens a dialog to view/edit a single shopping item's details,
/// then triggers [onReload] after saving.
Future<void> showShoppingItemDialog(
  BuildContext context,
  TaskItemContext ctx,
  Future<void> Function() onReload,
) async {
  final item = ctx.taskItem;
  final descriptionController = TextEditingController(text: item.description);
  final purposeController = TextEditingController(text: item.purpose);
  final costController = TextEditingController(
    text: item.actualMaterialUnitCost?.toString() ?? '',
  );
  final quantityController = TextEditingController(
    text: item.actualMaterialQuantity?.toString() ?? '',
  );
  Supplier? selectedSupplier;
  if (item.supplierId != null) {
    selectedSupplier = await DaoSupplier().getById(item.supplierId);
  }

  if (!context.mounted) {
    return;
  }

  // Compute 80% of screen width, capped at 600
  final screenWidth = MediaQuery.of(context).size.width;
  final targetWidth = screenWidth * 0.8;
  final dialogWidth = targetWidth > 600 ? 600.0 : targetWidth;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setState) => AlertDialog(
        title: const Text('Item Details'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        content: SizedBox(
          width: dialogWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogCtx).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HMBTextField(
                    controller: descriptionController,
                    labelText: 'Description',
                  ),
                  const SizedBox(height: 8),
                  HMBTextArea(
                    controller: purposeController,
                    labelText: 'Purpose',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  HMBDroplist<Supplier>(
                    title: 'Supplier',
                    items: (filter) => DaoSupplier().getByFilter(filter),
                    format: (sup) => sup.name,
                    selectedItem: () async => selectedSupplier,
                    required: false,
                    onChanged: (sup) => setState(() => selectedSupplier = sup),
                  ),
                  const SizedBox(height: 8),
                  HMBTextField(
                    controller: costController,
                    labelText: 'Unit Cost',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  HMBTextField(
                    controller: quantityController,
                    labelText: 'Quantity',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // update fields
              item
                ..description = descriptionController.text
                ..purpose = purposeController.text
                ..actualMaterialUnitCost = MoneyEx.tryParse(costController.text)
                ..actualMaterialQuantity = FixedEx.tryParse(
                  quantityController.text,
                )
                ..supplierId = selectedSupplier?.id;
              await DaoTaskItem().update(item);
              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop();
              }
              await onReload();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

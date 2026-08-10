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
import 'package:money2/money2.dart';

import '../../dao/dao.g.dart';
import '../../entity/material_price.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/icons/hmb_undo_icon.dart';
import '../widgets/layout/layout.g.dart';
import 'list_packing_screen.dart';
import 'list_shopping_screen.dart';
import 'material_price_editor.dart';
import 'shopping_item_card.dart';

/// “Purchased” mode: perhaps a “view invoice” button.
class PurchasedItemCard extends ShoppingItemCard {
  const PurchasedItemCard({
    required super.itemContext,
    required super.details,
    required super.onReload,
    super.key,
  });

  @override
  Widget buildActions(BuildContext context, CustomerAndJob det) => HMBUndoIcon(
    onPressed: () async {
      await _markAsReturned(itemContext, context);
      await onReload();
    },
  );

  Future<void> _markAsReturned(
    TaskItemContext itemContext,
    BuildContext context,
  ) async {
    final originalPrice =
        itemContext.taskItem.actualPrice ?? itemContext.taskItem.estimatedPrice;
    if (originalPrice == null) {
      HMBToast.error('This item has no purchase price to return.');
      return;
    }
    final previousReturns = await DaoTaskItem().getReturnsFor(
      itemContext.taskItem.id,
    );
    final returnedQuantity = previousReturns
        .map((item) => item.actualPrice)
        .whereType<MaterialPrice>()
        .where((price) => price.mode == originalPrice.mode)
        .fold(Fixed.zero, (total, price) => total + price.quantity);
    final remainingQuantity = originalPrice.quantity - returnedQuantity;
    if (!remainingQuantity.isPositive) {
      HMBToast.error('This purchase has already been fully returned.');
      return;
    }
    if (!context.mounted) {
      return;
    }
    final remainingPrice = originalPrice.isPackagePrice
        ? MaterialPrice.packages(
            packageCount: remainingQuantity,
            packageCost: originalPrice.unitCost,
            itemsPerPackage: originalPrice.itemsPerPackage!,
          )
        : MaterialPrice.items(
            quantity: remainingQuantity,
            unitCost: originalPrice.unitCost,
          );
    final priceController = MaterialPriceEditingController(
      price: remainingPrice,
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Return Item'),
          content: HMBColumn(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(itemContext.taskItem.description),
              MaterialPriceEditor(
                controller: priceController,
                title: 'Refund pricing',
                canChangeMode: false,
              ),
            ],
          ),
          actions: [
            HMBButton(
              onPressed: () => Navigator.pop(ctx, false),
              label: 'Cancel',
              hint: "Don't return this item",
            ),
            HMBButton(
              onPressed: () => Navigator.pop(ctx, true),
              label: 'Return',
              hint: 'Record this item as returned',
            ),
          ],
        ),
      );

      if (confirmed ?? false) {
        final returnPrice = priceController.value;
        if (returnPrice == null) {
          return;
        }
        if (returnPrice.mode != originalPrice.mode ||
            returnPrice.quantity > remainingQuantity) {
          HMBToast.error(
            'The return must use the purchase mode and cannot exceed '
            '$remainingQuantity.',
          );
          return;
        }
        await DaoTaskItem().markAsReturned(
          itemContext.taskItem.id,
          returnPrice,
        );
      }
    } finally {
      priceController.dispose();
    }
  }
}

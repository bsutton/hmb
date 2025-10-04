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

import 'package:fixed/fixed.dart';
import 'package:flutter/material.dart';

import '../../dao/dao.g.dart';
import '../../util/flutter/flutter_util.g.dart';
import '../widgets/icons/hmb_undo_icon.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/text/text.g.dart';
import 'list_packing_screen.dart';
import 'list_shopping_screen.dart';
import 'shopping_item_card.dart';

/// “Purchased” mode: perhaps a “view invoice” button.
class PurchasedItemCard extends ShoppingItemCard {
  const PurchasedItemCard({
    required super.itemContext,
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
    final qtyCtrl = TextEditingController(
      text: (itemContext.taskItem.actualMaterialQuantity ?? Fixed.one)
          .toString(),
    );
    final refundCtrl = TextEditingController(
      text: itemContext.taskItem.actualMaterialUnitCost.toString(),
    );

    final totalCost =
        (itemContext.taskItem.actualMaterialUnitCost ?? MoneyEx.zero)
            .multiplyByFixed(
              itemContext.taskItem.actualMaterialQuantity ?? Fixed.zero,
            );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Return Item'),
        content: HMBColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(itemContext.taskItem.description),
            TextField(
              controller: qtyCtrl,
              decoration: const InputDecoration(
                labelText: 'Quantity to return',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: refundCtrl,
              decoration: const InputDecoration(
                labelText: 'Refund amount each',
              ),
              keyboardType: TextInputType.number,
            ),
            HMBText('Total: $totalCost'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Return'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      final qty = Fixed.tryParse(qtyCtrl.text) ?? Fixed.one;
      final refund = MoneyEx.tryParse(refundCtrl.text);
      await DaoTaskItem().markAsReturned(itemContext.taskItem.id, qty, refund);
    }
  }
}

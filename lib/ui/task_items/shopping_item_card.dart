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
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao.g.dart';
import '../../util/dart/types.dart';
import '../dialog/hmb_comfirm_delete_dialog.dart';
import '../widgets/icons/hmb_delete_icon.dart';
import '../widgets/icons/hmb_edit_icon.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/widgets.g.dart';
import 'item_card_common.dart';
import 'list_packing_screen.dart';
import 'list_shopping_screen.dart';
import 'shopping_item_dialog.dart';

/// Base card for a shopping item. Tapping the card opens its detail/edit dialog
/// and then calls [onReload] after edits.
abstract class ShoppingItemCard extends StatelessWidget {
  final TaskItemContext itemContext;
  final AsyncVoidCallback onReload;

  const ShoppingItemCard({
    required this.itemContext,
    required this.onReload,
    super.key,
  });

  /// Build specific action buttons (e.g. ✓ for purchase, ↩ for return).
  Widget buildActions(BuildContext context, CustomerAndJob det);

  bool get showDeleteAction => true;

  @override
  Widget build(BuildContext context) => FutureBuilderEx<CustomerAndJob>(
    future: CustomerAndJob.fetch(itemContext),
    builder: (context, details) => SurfaceCardWithActions(
      title: itemContext.taskItem.description,
      actions: [
        buildActions(context, details!),
        HMBEditIcon(
          onPressed: () =>
              showShoppingItemDialog(context, itemContext, onReload),
          hint: 'Edit Item',
        ),
        if (showDeleteAction)
          HMBDeleteIcon(
            hint: 'Delete Item',
            onPressed: () => _deleteItem(context),
          ),
      ],
      height: 340,
      body: HMBRow(
        children: [
          // <-- Make the text column take all available space
          Expanded(
            child: ItemCardCommon(
              customerAndJob: details,
              taskItem: itemContext.taskItem,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _deleteItem(BuildContext context) async {
    final taskItem = itemContext.taskItem;
    if (taskItem.billed) {
      HMBToast.error("You can't delete an item that has been invoiced.");
      return;
    }

    await showConfirmDeleteDialog(
      context: context,
      nameSingular: 'Item',
      question: 'Are you sure you want to delete ${taskItem.description}?',
      onConfirmed: () async {
        try {
          await DaoTaskItem().delete(taskItem.id);
          await onReload();
          HMBToast.info('Item deleted.');
        } catch (e) {
          HMBToast.error('Unable to delete item: $e');
        }
      },
    );
  }
}

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
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../util/types.dart';
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

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showShoppingItemDialog(context, itemContext, onReload),
    child: SurfaceCard(
      title: itemContext.taskItem.description,
      height: 260,
      body: FutureBuilderEx<CustomerAndJob>(
        future: CustomerAndJob.fetch(itemContext),
        builder: (_, details) {
          final det = details!;
          return Row(
            children: [
              // <-- Make the text column take all available space
              Expanded(
                child: ItemCardCommon(
                  customerAndJob: det,
                  taskItem: itemContext.taskItem,
                ),
              ),
              const SizedBox(width: 8),
              // <-- Action buttons stay at their intrinsic size
              buildActions(context, det),
            ],
          );
        },
      ),
    ),
  );
}

// ignore_for_file: discarded_futures

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../widgets/widgets.g.dart';
import 'item_card_common.dart';
import 'list_packing_screen.dart';
import 'list_shopping_screen.dart';
import 'shopping_item_dialog.dart';

/// Base card for a shopping item. Tapping the card opens its detail/edit dialog
/// and then calls [onReload] after edits.
abstract class ShoppingItemCard extends StatelessWidget {
  const ShoppingItemCard({
    required this.itemContext,
    required this.onReload,

    super.key,
  });

  final TaskItemContext itemContext;
  final Future<void> Function() onReload;

  /// Build specific action buttons (e.g. ✓ for purchase, ↩ for return).
  Widget buildActions(BuildContext context, CustomerAndJob det);

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showShoppingItemDialog(context, itemContext, onReload),
    child: SurfaceCard(
      title: itemContext.taskItem.description,
      height: 240,
      body: FutureBuilderEx<CustomerAndJob>(
        future: CustomerAndJob.fetch(itemContext),
        builder: (_, details) {
          final det = details!;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ItemCardCommon(
                customerAndJob: det,
                taskItem: itemContext.taskItem,
              ),
              buildActions(context, det),
            ],
          );
        },
      ),
    ),
  );
}

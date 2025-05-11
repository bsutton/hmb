// ignore_for_file: discarded_futures

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../entity/entity.g.dart';
import '../widgets/widgets.g.dart';
import 'item_card_common.dart';
import 'list_packing_screen.dart';
import 'list_shopping_screen.dart';

/// Base card for a shopping item.
abstract class ShoppingItemCard extends StatelessWidget {
  const ShoppingItemCard({required this.itemContext, super.key});
  final TaskItemContext itemContext;

  /// Subclasses implement this to produce the row of action buttons.
  Widget buildActions(
    BuildContext context,
    CustomerAndJob det,
    TaskItem taskItem,
  );

  @override
  Widget build(BuildContext context) => SurfaceCard(
    title: itemContext.taskItem.description,
    height: 240,
    body: FutureBuilderEx<CustomerAndJob>(
      future: CustomerAndJob.fetch(itemContext),
      builder: (_, details) {
        final det = details!;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ItemCardCommon(customerAndJob: det, taskItem: itemContext.taskItem),
            buildActions(context, det, itemContext.taskItem),
          ],
        );
      },
    ),
  );
}

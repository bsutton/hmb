// ignore_for_file: discarded_futures

import 'package:flutter/material.dart';

import '../../entity/entity.g.dart';
import 'list_shopping_screen.dart';
import 'mark_as_complete.dart';
import 'shopping_item_card.dart';

/// “To Purchase” mode: just a ✓ button.
class ToPurchaseItemCard extends ShoppingItemCard {
  const ToPurchaseItemCard({
    required this.onReload,
    required super.itemContext,
    super.key,
  });

  final Future<void> Function() onReload;

  @override
  Widget buildActions(
    BuildContext context,
    CustomerAndJob det,
    TaskItem taskItem,
  ) => IconButton(
    icon: const Icon(Icons.check, color: Colors.green),
    onPressed: () async {
      await markAsCompleted(itemContext, context);
      await onReload();
    },
  );
}

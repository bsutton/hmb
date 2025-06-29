/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// ignore_for_file: discarded_futures

import 'package:flutter/material.dart';

import 'list_shopping_screen.dart';
import 'mark_as_complete.dart';
import 'shopping_item_card.dart';

/// “To Purchase” mode: just a ✓ button.
class ToPurchaseItemCard extends ShoppingItemCard {
  const ToPurchaseItemCard({
    required super.onReload,
    required super.itemContext,
    super.key,
  });

  @override
  Widget buildActions(BuildContext context, CustomerAndJob det) => IconButton(
    icon: const Icon(Icons.check, color: Colors.green),
    onPressed: () async {
      await markAsCompleted(itemContext, context);
      await onReload();
    },
  );
}

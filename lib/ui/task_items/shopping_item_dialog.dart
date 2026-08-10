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

// lib/ui/screens/shopping_item_card.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:strings/strings.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../dao/dao_supplier.dart';
import '../../dao/dao_task_item.dart';
import '../../entity/supplier.dart';
import '../../util/dart/types.dart';
import '../widgets/fields/fields.g.dart';
import '../widgets/hmb_button.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_droplist.dart';
import 'task_items.g.dart';

/// Opens a dialog to view/edit a single shopping item's details,
/// then triggers [onReload] after saving.
Future<void> showShoppingItemDialog(
  BuildContext context,
  TaskItemContext ctx,
  AsyncVoidCallback onReload,
) async {
  final item = ctx.taskItem;
  final descriptionController = TextEditingController(text: item.description);
  final purposeController = TextEditingController(text: item.purpose);
  final priceController = MaterialPriceEditingController(
    price: item.completed
        ? item.actualPrice ?? item.estimatedPrice
        : item.estimatedPrice,
  );
  Supplier? selectedSupplier;
  if (item.supplierId != null) {
    selectedSupplier = await DaoSupplier().getById(item.supplierId);
  }

  // Prepare URL
  final url = item.url;

  if (!context.mounted) {
    return;
  }

  // Compute 80% of screen width, capped at 600
  final screenWidth = MediaQuery.of(context).size.width;
  final targetWidth = screenWidth * 0.8;
  final dialogWidth = targetWidth > 600 ? 600.0 : targetWidth;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          title: const Text('Item Details'),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          content: SizedBox(
            width: dialogWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogCtx).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: HMBColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.hasDimensions) ...[
                      Text(
                        'Dimensions: ${item.dimensions}',
                        style: Theme.of(dialogCtx).textTheme.bodyMedium,
                      ),
                    ],
                    HMBTextField(
                      controller: descriptionController,
                      labelText: 'Description',
                    ),
                    HMBTextArea(
                      controller: purposeController,
                      labelText: 'Purpose',
                      maxLines: 2,
                    ),
                    if (Strings.isNotBlank(url)) ...[
                      InkWell(
                        onTap: () async {
                          final uri = Uri.tryParse(url);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        child: Text(
                          url,
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                    HMBDroplist<Supplier>(
                      title: 'Supplier',
                      items: (filter) => DaoSupplier().getByFilter(filter),
                      format: (sup) => sup.name,
                      selectedItem: () async => selectedSupplier,
                      required: false,
                      onChanged: (sup) {
                        unawaited(DaoSupplier().recordAccess(sup?.id));
                        setState(() => selectedSupplier = sup);
                      },
                    ),
                    MaterialPriceEditor(
                      controller: priceController,
                      title: item.completed
                          ? 'Actual pricing'
                          : 'Estimated pricing',
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            HMBButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              label: 'Cancel',
              hint: "Don't save changes to this item",
            ),
            HMBButton(
              onPressed: () async {
                final price = priceController.value;
                if (price == null) {
                  return;
                }
                final updated = item.copyWith(
                  description: descriptionController.text,
                  purpose: purposeController.text,
                  supplierId: selectedSupplier?.id,
                  estimatedPrice: item.completed ? null : price,
                  actualPrice: item.completed ? price : null,
                );
                if (item.completed) {
                  updated.setActualPrice(price);
                }
                await DaoTaskItem().update(updated);
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
                await onReload();
              },
              label: 'Save',
              hint: 'Save changes to this item',
            ),
          ],
        ),
      ),
    );
  } finally {
    descriptionController.dispose();
    purposeController.dispose();
    priceController.dispose();
  }
}

/*
 Copyright © OnePub IP Pty Ltd.
 S. Brett Sutton. All Rights Reserved.
*/

import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../../entity/material_price.dart';
import '../../util/dart/fixed_ex.dart';
import '../widgets/fields/hmb_integer_field.dart';
import '../widgets/fields/hmb_text_field.dart';
import '../widgets/layout/layout.g.dart';

class MaterialPriceEditingController {
  MaterialPriceEditingController({MaterialPrice? price})
    : mode = price?.mode ?? MaterialPriceEntryMode.items,
      quantity = TextEditingController(),
      unitCost = TextEditingController(),
      itemsPerPackage = TextEditingController() {
    if (price == null) {
      itemsPerPackage.text = '1';
    } else {
      _applyPrice(price);
    }
    _rememberCurrentDraft();
  }

  MaterialPriceEntryMode mode;
  final TextEditingController quantity;
  final TextEditingController unitCost;
  final TextEditingController itemsPerPackage;
  _MaterialPriceDraft? _itemDraft;
  _MaterialPriceDraft? _packageDraft;

  MaterialPrice? get value {
    final parsedQuantity = Fixed.tryParse(quantity.text, decimalDigits: 3);
    final parsedUnitCost = Money.tryParse(
      unitCost.text,
      isoCode: 'AUD',
      decimalDigits: 2,
    );
    if (parsedQuantity == null ||
        !parsedQuantity.isPositive ||
        parsedUnitCost == null ||
        parsedUnitCost.isNegative) {
      return null;
    }
    if (mode == MaterialPriceEntryMode.packages) {
      final packageCount = int.tryParse(quantity.text);
      final packageSize = int.tryParse(itemsPerPackage.text);
      if (packageCount == null ||
          packageCount <= 0 ||
          packageSize == null ||
          packageSize <= 0) {
        return null;
      }
      return MaterialPrice.packages(
        packageCount: Fixed.fromNum(packageCount, decimalDigits: 3),
        packageCost: parsedUnitCost,
        itemsPerPackage: Fixed.fromNum(packageSize, decimalDigits: 3),
      );
    }
    return MaterialPrice.items(
      quantity: parsedQuantity,
      unitCost: parsedUnitCost,
    );
  }

  void changeMode(MaterialPriceEntryMode nextMode) {
    if (mode == nextMode) {
      return;
    }
    final current = value;
    _rememberCurrentDraft();
    mode = nextMode;

    final draft = nextMode == MaterialPriceEntryMode.items
        ? _itemDraft
        : _packageDraft;
    if (draft != null) {
      _applyDraft(draft);
    } else if (current != null) {
      _applyConvertedPrice(current, nextMode);
    }
  }

  void setPrice(MaterialPrice price) {
    _itemDraft = null;
    _packageDraft = null;
    mode = price.mode;
    _applyPrice(price);
    _rememberCurrentDraft();
  }

  /// Discards a stale draft in the other mode once this mode has a valid edit.
  ///
  /// The next mode switch will derive fresh equivalent values. Invalid,
  /// partially-entered values leave the other draft intact so the user can
  /// still switch back to it.
  void markCurrentModeEdited() {
    if (value == null) {
      return;
    }
    if (mode == MaterialPriceEntryMode.items) {
      _packageDraft = null;
    } else {
      _itemDraft = null;
    }
  }

  void _applyPrice(MaterialPrice price) {
    quantity.text = price.isPackagePrice
        ? price.quantity.toInt().toString()
        : price.quantity.compact();
    unitCost.text = price.unitCost.toString();
    itemsPerPackage.text = price.itemsPerPackage?.toInt().toString() ?? '1';
  }

  void _applyConvertedPrice(
    MaterialPrice price,
    MaterialPriceEntryMode nextMode,
  ) {
    if (nextMode == MaterialPriceEntryMode.items) {
      quantity.text = price.totalItemQuantity.compact();
      unitCost.text = price.equivalentItemCost.toString();
      itemsPerPackage.text = '1';
    } else {
      quantity.text = '1';
      itemsPerPackage.text = price.totalItemQuantity.decimalPart == BigInt.zero
          ? price.totalItemQuantity.toInt().toString()
          : '1';
      unitCost.text = price.totalCost.toString();
    }
  }

  void _rememberCurrentDraft() {
    final draft = _MaterialPriceDraft(
      quantity: quantity.text,
      unitCost: unitCost.text,
      itemsPerPackage: itemsPerPackage.text,
    );
    if (mode == MaterialPriceEntryMode.items) {
      _itemDraft = draft;
    } else {
      _packageDraft = draft;
    }
  }

  void _applyDraft(_MaterialPriceDraft draft) {
    quantity.text = draft.quantity;
    unitCost.text = draft.unitCost;
    itemsPerPackage.text = draft.itemsPerPackage;
  }

  void dispose() {
    quantity.dispose();
    unitCost.dispose();
    itemsPerPackage.dispose();
  }
}

class _MaterialPriceDraft {
  const _MaterialPriceDraft({
    required this.quantity,
    required this.unitCost,
    required this.itemsPerPackage,
  });

  final String quantity;
  final String unitCost;
  final String itemsPerPackage;
}

/// Consistent editor for individual-item and package material prices.
class MaterialPriceEditor extends StatefulWidget {
  const MaterialPriceEditor({
    required this.controller,
    this.title,
    this.onChanged,
    this.canChangeMode = true,
    super.key,
  });

  final MaterialPriceEditingController controller;
  final String? title;
  final ValueChanged<MaterialPrice?>? onChanged;
  final bool canChangeMode;

  @override
  State<MaterialPriceEditor> createState() => _MaterialPriceEditorState();
}

class _MaterialPriceEditorState extends State<MaterialPriceEditor> {
  String? _positiveNumber(String? value) {
    final parsed = Fixed.tryParse(value ?? '', decimalDigits: 3);
    if (parsed == null || !parsed.isPositive) {
      return 'Enter a value greater than zero';
    }
    return null;
  }

  String? _nonNegativeMoney(String? value) {
    final parsed = Money.tryParse(
      value ?? '',
      isoCode: 'AUD',
      decimalDigits: 2,
    );
    if (parsed == null || parsed.isNegative) {
      return 'Enter a valid cost';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final price = controller.value;
    final isPackages = controller.mode == MaterialPriceEntryMode.packages;

    final quantityField = isPackages
        ? HMBIntegerField(
            controller: controller.quantity,
            labelText: 'Number of packages',
            required: true,
            positive: true,
            onChanged: (_) => _fieldChanged(),
          )
        : HMBTextField(
            controller: controller.quantity,
            labelText: 'Quantity',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            required: true,
            validator: _positiveNumber,
            onChanged: (_) => _fieldChanged(),
          );
    final costField = HMBTextField(
      controller: controller.unitCost,
      labelText: isPackages ? 'Cost per package' : 'Cost per item',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      required: true,
      validator: _nonNegativeMoney,
      onChanged: (_) => _fieldChanged(),
    );
    final packageSizeField = HMBIntegerField(
      controller: controller.itemsPerPackage,
      labelText: 'Items per package',
      required: true,
      positive: true,
      onChanged: (_) => _fieldChanged(),
    );

    return HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.title != null)
          Text(widget.title!, style: Theme.of(context).textTheme.titleMedium),
        SegmentedButton<MaterialPriceEntryMode>(
          segments: const [
            ButtonSegment(
              value: MaterialPriceEntryMode.items,
              label: Text('Individual items'),
            ),
            ButtonSegment(
              value: MaterialPriceEntryMode.packages,
              label: Text('Packages'),
            ),
          ],
          selected: {controller.mode},
          onSelectionChanged: widget.canChangeMode
              ? (selection) {
                  controller.changeMode(selection.single);
                  _changed();
                }
              : null,
        ),
        if (MediaQuery.sizeOf(context).width < 700)
          HMBColumn(
            children: [
              if (isPackages) packageSizeField,
              quantityField,
              costField,
            ],
          )
        else
          HMBRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPackages) Expanded(child: packageSizeField),
              Expanded(child: quantityField),
              Expanded(child: costField),
            ],
          ),
        if (price != null)
          Text(
            isPackages
                ? 'Total: ${price.totalItemQuantity.toInt()} items · '
                      '${price.equivalentItemCost} each · '
                      '${price.totalCost}'
                : 'Total: ${price.totalItemQuantity.compact()} items · '
                      '${price.totalCost}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  void _changed() {
    setState(() {});
    widget.onChanged?.call(widget.controller.value);
  }

  void _fieldChanged() {
    widget.controller.markCurrentModeEdited();
    _changed();
  }
}

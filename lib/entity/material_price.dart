/*
 Copyright © OnePub IP Pty Ltd.
 S. Brett Sutton. All Rights Reserved.
*/

import 'package:money2/money2.dart';

import '../util/dart/fixed_ex.dart';
import '../util/dart/money_ex.dart';

/// How a material price was entered.
enum MaterialPriceEntryMode {
  items,
  packages;

  static MaterialPriceEntryMode? fromSql(String? value) {
    if (value == null) {
      return null;
    }
    return MaterialPriceEntryMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => MaterialPriceEntryMode.items,
    );
  }
}

/// A complete material price, preserving how the supplier sold the material.
///
/// In [MaterialPriceEntryMode.items] mode, [quantity] is the number of items
/// and [unitCost] is the cost of one item. In package mode, they are the
/// number of packages and cost of one package respectively.
class MaterialPrice {
  const MaterialPrice._({
    required this.mode,
    required this.quantity,
    required this.unitCost,
    required this.itemsPerPackage,
  });

  factory MaterialPrice.items({
    required Fixed quantity,
    required Money unitCost,
  }) => MaterialPrice._(
    mode: MaterialPriceEntryMode.items,
    quantity: quantity,
    unitCost: unitCost,
    itemsPerPackage: null,
  );

  factory MaterialPrice.packages({
    required Fixed packageCount,
    required Money packageCost,
    required Fixed itemsPerPackage,
  }) {
    if (!packageCount.isPositive || !_isWhole(packageCount)) {
      throw ArgumentError.value(
        packageCount,
        'packageCount',
        'must be a whole number greater than zero',
      );
    }
    if (!itemsPerPackage.isPositive || !_isWhole(itemsPerPackage)) {
      throw ArgumentError.value(
        itemsPerPackage,
        'itemsPerPackage',
        'must be a whole number greater than zero',
      );
    }
    return MaterialPrice._(
      mode: MaterialPriceEntryMode.packages,
      quantity: packageCount,
      unitCost: packageCost,
      itemsPerPackage: itemsPerPackage,
    );
  }

  factory MaterialPrice.fromMap(
    Map<String, dynamic> map, {
    required String prefix,
  }) {
    final mode = MaterialPriceEntryMode.fromSql(
      map['${prefix}_price_mode'] as String?,
    );
    final quantity = FixedEx.fromIntOrNull(map['${prefix}_quantity'] as int?);
    final unitCost = MoneyEx.moneyOrNull(map['${prefix}_unit_cost'] as int?);
    if (mode == null || quantity == null || unitCost == null) {
      throw ArgumentError('Incomplete $prefix material price');
    }
    if (mode == MaterialPriceEntryMode.packages) {
      final itemsPerPackage = FixedEx.fromIntOrNull(
        map['${prefix}_items_per_package'] as int?,
      );
      if (itemsPerPackage == null) {
        throw ArgumentError('Missing $prefix items per package');
      }
      return MaterialPrice.packages(
        packageCount: quantity,
        packageCost: unitCost,
        itemsPerPackage: itemsPerPackage,
      );
    }
    return MaterialPrice.items(quantity: quantity, unitCost: unitCost);
  }

  static MaterialPrice? fromMapOrNull(
    Map<String, dynamic> map, {
    required String prefix,
  }) {
    if (map['${prefix}_price_mode'] == null &&
        map['${prefix}_quantity'] == null &&
        map['${prefix}_unit_cost'] == null) {
      return null;
    }
    return MaterialPrice.fromMap(map, prefix: prefix);
  }

  final MaterialPriceEntryMode mode;
  final Fixed quantity;
  final Money unitCost;
  final Fixed? itemsPerPackage;

  bool get isPackagePrice => mode == MaterialPriceEntryMode.packages;

  Fixed get totalItemQuantity =>
      isPackagePrice ? quantity * itemsPerPackage! : quantity;

  Money get totalCost => unitCost.multiplyByFixed(quantity);

  Money get equivalentItemCost {
    if (!isPackagePrice || itemsPerPackage!.isZero) {
      return unitCost;
    }
    return unitCost.divideByFixed(itemsPerPackage!);
  }

  Map<String, dynamic> toMap({required String prefix}) => {
    '${prefix}_price_mode': mode.name,
    '${prefix}_quantity': quantity.threeDigits().minorUnits.toInt(),
    '${prefix}_unit_cost': unitCost.twoDigits().minorUnits.toInt(),
    '${prefix}_items_per_package': itemsPerPackage
        ?.threeDigits()
        .minorUnits
        .toInt(),
  };

  static bool _isWhole(Fixed value) => value.decimalPart == BigInt.zero;
}

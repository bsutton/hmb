import 'package:hmb/entity/material_price.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

void main() {
  test('individual item pricing derives its total', () {
    final price = MaterialPrice.items(
      quantity: Fixed.parse('2.5'),
      unitCost: MoneyEx.fromInt(400),
    );

    expect(price.totalItemQuantity, Fixed.parse('2.5'));
    expect(price.equivalentItemCost, MoneyEx.fromInt(400));
    expect(price.totalCost, MoneyEx.fromInt(1000));
  });

  test('package pricing preserves package inputs and exact package total', () {
    final price = MaterialPrice.packages(
      packageCount: Fixed.parse('3'),
      packageCost: MoneyEx.fromInt(1000),
      itemsPerPackage: Fixed.parse('6'),
    );

    expect(price.quantity, Fixed.parse('3'));
    expect(price.itemsPerPackage, Fixed.parse('6'));
    expect(price.totalItemQuantity, Fixed.parse('18'));
    expect(price.totalCost, MoneyEx.fromInt(3000));
    expect(price.equivalentItemCost, MoneyEx.fromInt(167));
  });

  test('package pricing round trips through database values', () {
    final original = MaterialPrice.packages(
      packageCount: Fixed.parse('2'),
      packageCost: MoneyEx.fromInt(1299),
      itemsPerPackage: Fixed.parse('5'),
    );

    final restored = MaterialPrice.fromMap(
      original.toMap(prefix: 'actual'),
      prefix: 'actual',
    );

    expect(restored.mode, MaterialPriceEntryMode.packages);
    expect(restored.quantity, original.quantity);
    expect(restored.unitCost, original.unitCost);
    expect(restored.itemsPerPackage, original.itemsPerPackage);
  });

  test('package count must be a positive whole number', () {
    expect(
      () => MaterialPrice.packages(
        packageCount: Fixed.parse('0.5'),
        packageCost: MoneyEx.fromInt(1299),
        itemsPerPackage: Fixed.parse('5'),
      ),
      throwsArgumentError,
    );
  });

  test('items per package must be a positive whole number', () {
    expect(
      () => MaterialPrice.packages(
        packageCount: Fixed.parse('2'),
        packageCost: MoneyEx.fromInt(1299),
        itemsPerPackage: Fixed.parse('2.5'),
      ),
      throwsArgumentError,
    );
  });
}

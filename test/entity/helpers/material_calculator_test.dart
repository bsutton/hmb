// test/material_calculator_test.dart
//
// Covers: charge modes (calculated/userDefined), billing types
// (fixedPrice/timeAndMaterial/nonBillable), completed/estimated vs actual,
// returns (negative totals), and calcMaterialCharges().
//
// Style prefs observed: <=80 cols, braces on single-line ifs.

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/entity/helpers/material_calculator.dart';
import 'package:hmb/entity/job.dart'; // for BillingType
import 'package:hmb/entity/task_item.dart';
import 'package:mocktail/mocktail.dart';
import 'package:money2/money2.dart';

void main() {
  // Use a known currency to avoid accidental mismatch with MoneyEx.zero.
  // If your app binds AUD globally already, keep this as is.
  final aud = Currency.create('AUD', 2);

  // Money $(int cents) => Money.fromIntWithCurrency(cents, aud); // helper
  Money dollars(num d) =>
      Money.parseWithCurrency(d.toStringAsFixed(2), aud); // convenience

  // A tiny helper for Fixed. If your Fixed has a different ctor, update here.
  Fixed qty(num v) => Fixed.parse(v.toString());

  setUpAll(() {
    registerFallbackValue(ChargeMode.calculated);
  });

  group('MaterialCalculator for Fixed Price (calculated)', () {
    test('multiplies unit cost by qty, applies margin on line only', () {
      final item = _MockTaskItem();
      when(() => item.chargeMode).thenReturn(ChargeMode.calculated);
      when(() => item.estimatedMaterialUnitCost).thenReturn(dollars(10));
      when(() => item.estimatedMaterialQuantity).thenReturn(qty(3));
      when(() => item.margin).thenReturn(Percentage.fromInt(2000));
      when(() => item.isReturn).thenReturn(false);

      final mc = MaterialCalculator(BillingType.fixedPrice, item);

      // line cost total = 10 * 3 = 30.00
      expect(mc.lineCostTotal, dollars(30));

      // unit charge reflects line total (with margin) / qty
      expect(mc.calculatedUnitCharge, dollars(12));

      // line charge total = 30.00 + 20% = 36.00
      expect(mc.lineChargeTotal, dollars(36));

      // calcMaterialCharges should match the line charge total
      expect(mc.calcMaterialCharges(BillingType.fixedPrice), dollars(36));
    });
  });

  group('MaterialCalculator.fixedPrice (userDefined)', () {
    test('uses user-defined line total and keeps cost total separate', () {
      final item = _MockTaskItem();
      when(() => item.chargeMode).thenReturn(ChargeMode.userDefined);
      when(() => item.estimatedMaterialUnitCost).thenReturn(dollars(7.5));
      when(() => item.estimatedMaterialQuantity).thenReturn(qty(5));
      when(() => item.userDefinedCharge).thenReturn(dollars(100));
      when(() => item.isReturn).thenReturn(false);

      final mc = MaterialCalculator(BillingType.fixedPrice, item);

      // line cost total = 7.50 * 5 = 37.50
      expect(mc.lineCostTotal, dollars(37.50));

      // user-defined line charge total = 100.00
      expect(mc.lineChargeTotal, dollars(100));

      expect(mc.calcMaterialCharges(BillingType.fixedPrice), dollars(100));
    });
  });

  group('MaterialCalculator.timeAndMaterials', () {
    test('NOT completed → uses estimated unit/qty', () {
      final item = _MockTaskItem();
      when(() => item.completed).thenReturn(false);
      when(() => item.chargeMode).thenReturn(ChargeMode.calculated);
      when(() => item.estimatedMaterialUnitCost).thenReturn(dollars(4.25));
      when(() => item.estimatedMaterialQuantity).thenReturn(qty(8));
      when(() => item.margin).thenReturn(Percentage.fromInt(1000));
      when(() => item.isReturn).thenReturn(false);

      final mc = MaterialCalculator(BillingType.timeAndMaterial, item);

      // cost = 4.25 * 8 = 34.00
      expect(mc.lineCostTotal, dollars(34));

      // unit charge reflects line total (with margin) / qty
      expect(mc.calculatedUnitCharge, dollars(4.68));

      // charge = 34.00 + 10% = 37.40 (line-level margin)
      expect(mc.lineChargeTotal, dollars(37.40));

      expect(
        mc.calcMaterialCharges(BillingType.timeAndMaterial),
        dollars(37.40),
      );
    });

    test('T&M completed → uses ACTUAL unit/qty', () {
      final item = _MockTaskItem();
      when(() => item.completed).thenReturn(true);
      when(() => item.chargeMode).thenReturn(ChargeMode.calculated);
      when(() => item.actualMaterialUnitCost).thenReturn(dollars(5.00));
      when(() => item.actualMaterialQuantity).thenReturn(qty(2.5));
      when(() => item.margin).thenReturn(Percentage.fromInt(5000));
      when(() => item.isReturn).thenReturn(false);

      final mc = MaterialCalculator(BillingType.timeAndMaterial, item);

      // cost = 5.00 * 2.5 = 12.50
      expect(mc.lineCostTotal, dollars(12.50));

      // unit charge reflects line total (with margin) / qty
      expect(mc.calculatedUnitCharge, dollars(7.50));

      // charge = 12.50 + 50% = 18.75
      expect(mc.lineChargeTotal, dollars(18.75));

      expect(
        mc.calcMaterialCharges(BillingType.timeAndMaterial),
        dollars(18.75),
      );
    });

    test('T&M userDefined → returns specified line total', () {
      final item = _MockTaskItem();
      when(() => item.completed).thenReturn(false);
      when(() => item.chargeMode).thenReturn(ChargeMode.userDefined);
      when(() => item.estimatedMaterialUnitCost).thenReturn(dollars(1.99));
      when(() => item.estimatedMaterialQuantity).thenReturn(qty(10));
      when(() => item.userDefinedCharge).thenReturn(dollars(15.25));
      when(() => item.isReturn).thenReturn(false);

      final mc = MaterialCalculator(BillingType.timeAndMaterial, item);

      // Cost still computed from unit/qty: 1.99 * 10 = 19.90
      expect(mc.lineCostTotal, dollars(19.90));

      // Charge is whatever the user defined
      expect(mc.lineChargeTotal, dollars(15.25));

      expect(
        mc.calcMaterialCharges(BillingType.timeAndMaterial),
        dollars(15.25),
      );
    });
  });

  group('T&M Returns (isReturn=true)', () {
    test('calculated: both cost and charge are negated', () {
      final item = _MockTaskItem();
      when(() => item.completed).thenReturn(false);
      when(() => item.chargeMode).thenReturn(ChargeMode.calculated);
      when(() => item.estimatedMaterialUnitCost).thenReturn(dollars(12));
      when(() => item.estimatedMaterialQuantity).thenReturn(qty(2));
      when(() => item.margin).thenReturn(Percentage.fromInt(2500));
      when(() => item.isReturn).thenReturn(true);

      final mc = MaterialCalculator(BillingType.timeAndMaterial, item);

      // Normal cost would be 24.00 → becomes -24.00
      expect(mc.lineCostTotal, dollars(-24));

      // Line charge = 24.00 + 25% = 30.00 → becomes -30.00
      expect(mc.lineChargeTotal, dollars(-30));

      expect(mc.calcMaterialCharges(BillingType.fixedPrice), dollars(-30));
    });

    test('T&M userDefined: user total is negated', () {
      final item = _MockTaskItem();
      when(() => item.completed).thenReturn(false);
      when(() => item.chargeMode).thenReturn(ChargeMode.userDefined);
      when(() => item.estimatedMaterialUnitCost).thenReturn(dollars(3));
      when(() => item.estimatedMaterialQuantity).thenReturn(qty(4));
      when(() => item.userDefinedCharge).thenReturn(dollars(50));
      when(() => item.isReturn).thenReturn(true);

      final mc = MaterialCalculator(BillingType.timeAndMaterial, item);

      // cost 12.00 → -12.00; user charge 50.00 → -50.00
      expect(mc.lineCostTotal, dollars(-12));
      expect(mc.lineChargeTotal, dollars(-50));
      expect(mc.calcMaterialCharges(BillingType.fixedPrice), dollars(-50));
    });
  });

  group('nonBillable delegates to timeAndMaterials', () {
    test('uses the same logic as T&M (calculated path)', () {
      final item = _MockTaskItem();
      when(() => item.completed).thenReturn(false);
      when(() => item.chargeMode).thenReturn(ChargeMode.calculated);
      when(() => item.estimatedMaterialUnitCost).thenReturn(dollars(2.40));
      when(() => item.estimatedMaterialQuantity).thenReturn(qty(3));
      when(() => item.margin).thenReturn(Percentage.fromInt(1000));
      when(() => item.isReturn).thenReturn(false);

      final mc = MaterialCalculator(BillingType.nonBillable, item);

      // cost = 2.40 * 3 = 7.20
      expect(mc.lineCostTotal, dollars(7.20));

      // non-billable forces charge to zero
      expect(mc.calculatedUnitCharge, dollars(0));
      expect(mc.lineChargeTotal, dollars(0));
      expect(mc.calcMaterialCharges(BillingType.nonBillable), dollars(0));
    });
  });
}

// ignore: avoid_implementing_value_types
class _MockTaskItem extends Mock implements TaskItem {}

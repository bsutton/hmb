// Covers line-level rounding for labour charge calculation.
// Style prefs: <=80 cols, braces on single-line ifs.

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/entity/helpers/labour_calculator.dart';
import 'package:hmb/entity/job.dart';
import 'package:hmb/entity/task_item.dart';
import 'package:mocktail/mocktail.dart';
import 'package:money2/money2.dart';

// ignore: avoid_implementing_value_types
class _MockTaskItem extends Mock implements TaskItem {}

void main() {
  // Bind a known currency for deterministic tests.
  final aud = Currency.create('AUD', 2);

  Money dollars(num d) => Money.parseWithCurrency(d.toStringAsFixed(2), aud);

  Fixed hrs(num v) => Fixed.parse(v.toString());

  setUpAll(() {
    registerFallbackValue(ChargeMode.calculated);
  });

  group('calculated (line-level margin) for Fixed Price Jobs', () {
    test('hours: cost = rate*hrs, charge = cost + margin', () {
      final t = _MockTaskItem();
      when(() => t.chargeMode).thenReturn(ChargeMode.calculated);
      when(() => t.labourEntryMode).thenReturn(LabourEntryMode.hours);
      when(() => t.estimatedLabourHours).thenReturn(hrs(2.5));
      when(() => t.margin).thenReturn(Percentage.fromInt(2000)); // 20%

      final hourly = dollars(80.00);

      final lc = LabourCalculator(BillingType.fixedPrice, t, hourly);

      // cost = 80 * 2.5 = 200.00
      expect(lc.cost, dollars(200.00));

      // charge = 200 + 20% = 240.00
      expect(lc.totalCharge, dollars(240.00));
    });

    test('dollars: cost from estimate, charge = cost + margin', () {
      final t = _MockTaskItem();
      when(() => t.chargeMode).thenReturn(ChargeMode.calculated);
      when(() => t.labourEntryMode).thenReturn(LabourEntryMode.dollars);
      when(() => t.estimatedLabourCost).thenReturn(dollars(150.00));
      when(() => t.margin).thenReturn(Percentage.fromInt(1000)); // 10%

      final lc = LabourCalculator(BillingType.fixedPrice, t, dollars(0));

      expect(lc.cost, dollars(150.00));
      expect(lc.totalCharge, dollars(165.00));
    });

    test('rounding edge (line-level): rate*hrs then margin', () {
      final t = _MockTaskItem();
      when(() => t.chargeMode).thenReturn(ChargeMode.calculated);
      when(() => t.labourEntryMode).thenReturn(LabourEntryMode.hours);
      when(() => t.estimatedLabourHours).thenReturn(hrs(8));
      when(() => t.margin).thenReturn(Percentage.fromInt(1000)); // 10%

      final hourly = dollars(4.25);
      final lc = LabourCalculator(BillingType.fixedPrice, t, hourly);

      // cost = 4.25 * 8 = 34.00
      expect(lc.cost, dollars(34.00));

      // charge = 34.00 + 10% = 37.40 (line-level rounding)
      expect(lc.totalCharge, dollars(37.40));
    });

    test('null inputs → zero-safe', () {
      final t = _MockTaskItem();
      when(() => t.chargeMode).thenReturn(ChargeMode.calculated);
      when(() => t.labourEntryMode).thenReturn(LabourEntryMode.hours);
      when(() => t.estimatedLabourHours).thenReturn(null);
      when(() => t.margin).thenReturn(Percentage.fromInt(1500));

      final lc = LabourCalculator(BillingType.fixedPrice, t, dollars(120));

      expect(lc.cost, dollars(0.00));
      expect(lc.totalCharge, dollars(0.00));
    });
  });

  group('userDefined (line total provided)', () {
    test('hours: cost and charge are user-defined line total', () {
      final t = _MockTaskItem();
      when(() => t.chargeMode).thenReturn(ChargeMode.userDefined);
      when(() => t.labourEntryMode).thenReturn(LabourEntryMode.hours);
      when(() => t.userDefinedCharge).thenReturn(dollars(300.00));

      final lc = LabourCalculator(BillingType.fixedPrice, t, dollars(80));

      expect(lc.cost, dollars(300.00));
      expect(lc.totalCharge, dollars(300.00));
    });

    test('dollars: cost and charge are user-defined line total', () {
      final t = _MockTaskItem();
      when(() => t.chargeMode).thenReturn(ChargeMode.userDefined);
      when(() => t.labourEntryMode).thenReturn(LabourEntryMode.dollars);
      when(() => t.userDefinedCharge).thenReturn(dollars(99.95));

      final lc = LabourCalculator(BillingType.fixedPrice, t, dollars(0));

      expect(lc.cost, dollars(99.95));
      expect(lc.totalCharge, dollars(99.95));
    });

    test('userDefined missing → zeros', () {
      final t = _MockTaskItem();
      when(() => t.chargeMode).thenReturn(ChargeMode.userDefined);
      when(() => t.labourEntryMode).thenReturn(LabourEntryMode.dollars);
      when(() => t.userDefinedCharge).thenReturn(null);

      final lc = LabourCalculator(BillingType.fixedPrice, t, dollars(0));

      expect(lc.cost, dollars(0.00));
      expect(lc.totalCharge, dollars(0.00));
    });
  });
}

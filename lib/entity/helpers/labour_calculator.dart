/*
 Copyright © OnePub IP Pty Ltd.
 S. Brett Sutton. All Rights Reserved.
*/

import 'package:money2/money2.dart';

import '../../util/dart/money_ex.dart';
import '../job.dart';
import '../task_item.dart';
import 'charge_mode.dart';

/// Calculates labour line totals. Applies margin at the **line** level
/// when [ChargeMode.calculated]. For [ChargeMode.userDefined] the
/// user value is taken as the final line total.
///
/// Notes:
/// - FP labour comes from estimates (hours or dollars).
/// - T&M labour should come from time tracking, not TaskItems.
///   If a labour TaskItem is present on a T&M task, we treat it
///   conservatively as zero charge (guarded at UI level).
class LabourCalculator {
  factory LabourCalculator(BillingType billing, TaskItem item, Money rate) {
    switch (billing) {
      case BillingType.nonBillable:
        {
          return LabourCalculator._(
            hourlyRate: rate,
            cost: MoneyEx.zero,
            totalCharge: MoneyEx.zero,
          );
        }
      case BillingType.fixedPrice:
        {
          return LabourCalculator.forFixedPrice(item, rate);
        }
      case BillingType.timeAndMaterial:
        {
          return LabourCalculator.forTimeAndMaterials(item, rate);
        }
    }
  }
  LabourCalculator._({
    required this.hourlyRate,
    required this.cost,
    required this.totalCharge,
  });

  final Money hourlyRate;

  /// Base cost before margin (line level).
  final Money cost;

  /// Final line charge (cost + margin) or user-defined.
  final Money totalCharge;

  // ---- Factory --------------------------------------------------------------

  factory LabourCalculator.forFixedPrice(TaskItem item, Money hourlyRate) {
    final base = _calcFpBaseCost(item, hourlyRate);
    final charge = _calcCharge(item, base);
    return LabourCalculator._(
      hourlyRate: hourlyRate,
      cost: base,
      totalCharge: charge,
    );
  }

  /// For T&M jobs, labour should be sourced from time entries, not
  /// TaskItems. If called by mistake, we return zero totals.
  factory LabourCalculator.forTimeAndMaterials(
    // ignore: avoid_unused_constructor_parameters
    TaskItem item,
    Money hourlyRate,
  ) => LabourCalculator._(
    hourlyRate: hourlyRate,
    cost: MoneyEx.zero,
    totalCharge: MoneyEx.zero,
  );

  // ---- Computation helpers --------------------------------------------------

  static Money _calcFpBaseCost(TaskItem item, Money hourlyRate) {
    switch (item.labourEntryMode) {
      case LabourEntryMode.dollars:
        {
          if (item.chargeMode == ChargeMode.userDefined) {
            return item.userDefinedCharge ?? MoneyEx.zero;
          }
          return item.estimatedLabourCost ?? MoneyEx.zero;
        }
      case LabourEntryMode.hours:
        {
          if (item.chargeMode == ChargeMode.userDefined) {
            return item.userDefinedCharge ?? MoneyEx.zero;
          }
          final hours = item.estimatedLabourHours;
          if (hours != null) {
            return hourlyRate.multiplyByFixed(hours);
          }
          return MoneyEx.zero;
        }
    }
  }

  static Money _calcCharge(TaskItem item, Money baseCost) {
    switch (item.chargeMode) {
      case ChargeMode.calculated:
        {
          return baseCost.plusPercentage(item.margin);
        }
      case ChargeMode.userDefined:
        {
          return item.userDefinedCharge ?? MoneyEx.zero;
        }
    }
  }
}

/*
 Copyright © OnePub IP Pty Ltd.
 S. Brett Sutton. All Rights Reserved.
*/

import 'package:money2/money2.dart';

import '../../util/dart/fixed_ex.dart';
import '../../util/dart/money_ex.dart';
import '../job.dart';
import '../task_item.dart';
import 'charge_mode.dart';

/// Calculates the cost/charge for material/consumable/tool items.
/// - Cost is always the base line (qty * unit cost), with sign applied
///   for returns.
/// - Charge is either user defined or calculated by applying [margin]
///   at the line level.
/// - For [BillingType.nonBillable], charge is always zero.
class MaterialCalculator {
  // ---- Construction ---------------------------------------------------------

  MaterialCalculator._calculated({
    required this.quantity,
    required this.unitCost,
    required this.margin,
    required this.isReturn,
  })  : chargeMode = ChargeMode.calculated,
        isNonBillable = false {
    var cost = unitCost.multiplyByFixed(quantity);
    var charge = cost.plusPercentage(margin);

    if (isReturn) {
      cost = -cost;
      charge = -charge;
    }

    lineCostTotal = cost;
    lineChargeTotal = charge;
  }

  MaterialCalculator._defined({
    required this.quantity,
    required this.unitCost,
    required Money definedLineTotal,
    required this.isReturn,
  })  : chargeMode = ChargeMode.userDefined,
        margin = Percentage.fromInt(0),
        isNonBillable = false {
    var cost = unitCost.multiplyByFixed(quantity);
    var charge = definedLineTotal;

    if (isReturn) {
      cost = -cost;
      charge = -charge;
    }

    lineCostTotal = cost;
    lineChargeTotal = charge;
  }

  MaterialCalculator._nonBillable({
    required this.quantity,
    required this.unitCost,
    required this.isReturn,
  })  : chargeMode = ChargeMode.calculated,
        margin = Percentage.fromInt(0),
        isNonBillable = true {
    var cost = unitCost.multiplyByFixed(quantity);
    if (isReturn) {
      cost = -cost;
    }
    lineCostTotal = cost;
    lineChargeTotal = MoneyEx.zero;
  }

  // ---- Factory selection ----------------------------------------------------

  factory MaterialCalculator(BillingType billingType, TaskItem item) {
    switch (billingType) {
      case BillingType.nonBillable: {
        return MaterialCalculator._nonBillable(
          quantity: _pickQtyFor(billingType, item),
          unitCost: _pickUnitFor(billingType, item),
          isReturn: item.isReturn,
        );
      }
      case BillingType.timeAndMaterial: {
        final qty = _pickQtyFor(billingType, item);
        final unit = _pickUnitFor(billingType, item);
        if (item.chargeMode == ChargeMode.userDefined) {
          return MaterialCalculator._defined(
            quantity: qty,
            unitCost: unit,
            definedLineTotal: item.userDefinedCharge ?? MoneyEx.zero,
            isReturn: item.isReturn,
          );
        } else {
          return MaterialCalculator._calculated(
            quantity: qty,
            unitCost: unit,
            margin: item.margin,
            isReturn: item.isReturn,
          );
        }
      }
      case BillingType.fixedPrice: {
        // FP uses estimates only; actuals are for P&L.
        final qty = item.estimatedMaterialQuantity ?? Fixed.one;
        final unit = item.estimatedMaterialUnitCost ?? MoneyEx.zero;
        if (item.chargeMode == ChargeMode.userDefined) {
          return MaterialCalculator._defined(
            quantity: qty,
            unitCost: unit,
            definedLineTotal: item.userDefinedCharge ?? MoneyEx.zero,
            isReturn: item.isReturn,
          );
        } else {
          return MaterialCalculator._calculated(
            quantity: qty,
            unitCost: unit,
            margin: item.margin,
            isReturn: item.isReturn,
          );
        }
      }
    }
  }

  static Fixed _pickQtyFor(BillingType billingType, TaskItem item) {
    if (billingType == BillingType.timeAndMaterial && item.completed) {
      return item.actualMaterialQuantity ?? item
          .estimatedMaterialQuantity ?? Fixed.one;
    }
    return item.estimatedMaterialQuantity ?? item
        .actualMaterialQuantity ?? Fixed.one;
  }

  static Money _pickUnitFor(BillingType billingType, TaskItem item) {
    if (billingType == BillingType.timeAndMaterial && item.completed) {
      return item.actualMaterialUnitCost ?? item
          .estimatedMaterialUnitCost ?? MoneyEx.zero;
    }
    return item.estimatedMaterialUnitCost ?? item
        .actualMaterialUnitCost ?? MoneyEx.zero;
  }

  // ---- Inputs / derived fields ---------------------------------------------

  late final Fixed quantity;
  late final Money unitCost;
  late final bool isReturn;

  /// When calculated, margin is applied to the **line** total.
  late final Percentage margin;

  /// Which mode produced [lineChargeTotal].
  final ChargeMode chargeMode;

  /// True when BillingType is Non-billable (charge forced to zero).
  final bool isNonBillable;

  // ---- Outputs --------------------------------------------------------------

  /// Base cost (no margin). Negative when [isReturn] is true.
  late final Money lineCostTotal;

  /// Final charge (margin applied at line level or user defined).
  /// For Non-billable, this is always zero.
  late final Money lineChargeTotal;

  /// Unit charge derived from [lineChargeTotal] / [quantity].
  /// Returns zero if quantity is zero.
  Money get calculatedUnitCharge {
    if (quantity.isZero) {
      return MoneyEx.zero;
    }
    return lineChargeTotal.divideByFixed(quantity);
  }

  /// The consumer API; returns the charge appropriate for the billing type.
  Money calcMaterialCharges(BillingType billingType) {
    if (billingType == BillingType.nonBillable) {
      return MoneyEx.zero;
    }
    return lineChargeTotal;
  }
}

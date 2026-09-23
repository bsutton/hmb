import 'package:money2/money2.dart';

import '../../util/dart/money_ex.dart';

/// Apply the job/task default only when the item has no custom margin.
///
/// [lineCharge] already includes the item's margin. Zero means inherit the
/// default; a nonzero item margin replaces it, never compounds with it.
/// An explicitly supplied whole-quote surcharge is a separate operation.
Money applyDefaultLineMargin(
  Money lineCharge, {
  required Percentage defaultMargin,
  required Percentage itemMargin,
}) {
  if (lineCharge.isZero || !itemMargin.isZero || defaultMargin.isZero) {
    return lineCharge;
  }
  return lineCharge.plusPercentage(defaultMargin);
}

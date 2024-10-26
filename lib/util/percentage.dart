import 'package:fixed/fixed.dart';
import 'package:strings/strings.dart';
// typedef Percentage = Fixed;

/// Percentage is described as a decimal
/// so 20% is expressed as 0.2
class Percentage extends Fixed {
  /// Creates a percentage.
  /// Pass 20 to get 20%
  /// For 20.5% use:
  /// ```
  /// Percentage(205, decimals: 3);
  // ignore: matching_super_parameters
  Percentage(super.percentage, {int decimals = 2})
      : super.fromInt(scale: decimals);

  factory Percentage.tryParse(String amount) {
    final fixed =
        Fixed.tryParse(Strings.orElseOnBlank(amount, '0'), scale: 3) ??
            Fixed.zero;

    return Percentage(fixed.minorUnits.toInt(), decimals: fixed.scale);
  }
  factory Percentage.fromInt(int? amount, {int decimals = 2}) {
    final fixed = Fixed.fromInt(amount ?? 0, scale: decimals);

    return Percentage(fixed.minorUnits.toInt(), decimals: fixed.scale);
  }
  static final Percentage zero = Percentage(0, decimals: 3);
  static final Percentage ten = Percentage(100, decimals: 3);
  static final Percentage twenty = Percentage(200, decimals: 3);
  static final Percentage onehundred = Percentage(1000, decimals: 3);

  @override
  String toString() => format('0.0%');
}

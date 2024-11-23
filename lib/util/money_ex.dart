import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import 'percentage.dart';

extension MoneyEx on Money {
  static Money get zero => Money.fromInt(0, isoCode: 'AUD', decimalDigits: 2);

  static Money tryParse(String? amount) =>
      Money.tryParse(Strings.orElseOnBlank(amount, '0'),
          isoCode: 'AUD', decimalDigits: 2) ??
      zero;

  static Money fromInt(int? amount) =>
      Money.fromInt(amount ?? 0, isoCode: 'AUD', decimalDigits: 2);

  static Money? moneyOrNull(int? amount) {
    if (amount == null) {
      return null;
    }
    return MoneyEx.fromInt(amount);
  }

  static Money dollars(int dollars) => fromInt(dollars * 100);

  static bool isZeroOrNull(Money? money) => money == null || money.isZero;

  /// Multiples this by the given percentage
  /// 1 * 20% = 0.2
  Money multipliedByPercentage(Percentage percentage) =>
      multiplyByFixed(percentage);

  /// Adds the given percentage to this amount
  /// 1 + 20 % = 1.2
  Money plusPercentage(Percentage percentage) =>
      multiplyByFixed(Fixed.one + percentage);
}

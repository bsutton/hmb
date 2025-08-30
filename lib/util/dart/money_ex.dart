/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

extension MoneyEx on Money {
  static Money get zero => Money.fromInt(0, isoCode: 'AUD', decimalDigits: 2);

  bool get isNonZero => !isZero;

  static Money tryParse(String? amount) =>
      Money.tryParse(
        Strings.orElseOnBlank(amount, '0'),
        isoCode: 'AUD',
        decimalDigits: 2,
      ) ??
      zero;

  static Money fromInt(int? amount) =>
      Money.fromInt(amount ?? 0, isoCode: 'AUD', decimalDigits: 2);

  Money twoDigits() => copyWith(decimalDigits: 2);

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
      this + this.multipliedByPercentage(percentage);
}

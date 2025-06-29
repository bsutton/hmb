/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

extension FixedEx on Fixed {
  static Fixed get zero => Fixed.fromInt(0);

  static Fixed tryParse(String? amount) =>
      Fixed.tryParse(Strings.orElseOnBlank(amount, '0'), decimalDigits: 3) ??
      zero;

  static Fixed tryParseOrElse(String? amount, Fixed orElse) {
    if (Strings.isBlank(amount)) {
      return orElse;
    }
    return Fixed.tryParse(amount ?? '', decimalDigits: 3) ?? orElse;
  }

  Fixed threeDigits() => copyWith(decimalDigits: 3);

  static Fixed fromInt(int? amount) =>
      Fixed.fromInt(amount ?? 0, decimalDigits: 3);

  static bool isZeroOrNull(Fixed? amount) => amount == null || amount.isZero;
}

import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

extension FixedEx on Fixed {
  static Fixed get zero => Fixed.fromInt(0);

  static Fixed tryParse(String? amount) =>
      Fixed.tryParse(Strings.orElseOnBlank(amount, '0'), decimalDigits: 3) ?? zero;

  static Fixed tryParseOrElse(String? amount, Fixed orElse) {
    if (Strings.isBlank(amount)) {
      return orElse;
    }
    return Fixed.tryParse(amount ?? '', decimalDigits: 3) ?? orElse;
  }

  Fixed threeDigits() => copyWith(decimalDigits: 3);

  static Fixed fromInt(int? amount) => Fixed.fromInt(amount ?? 0, decimalDigits: 3);

  static bool isZeroOrNull(Fixed? amount) => amount == null || amount.isZero;
}

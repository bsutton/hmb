import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

extension MoneyEx on Money {
  static Money get zero => Money.fromInt(0, isoCode: 'AUD', decimalDigits: 2);

  static Money tryParse(String? amount) =>
      Money.tryParse(Strings.orElseOnBlank(amount, '0'),
          isoCode: 'AUD', decimalDigits: 2) ??
      zero;

  static Money fromInt(int? amount) =>
      Money.fromInt(amount ?? 0, isoCode: 'AUD', decimalDigits: 2);

  static Money dollars(int dollars) => fromInt(dollars * 100);

  static bool isZeroOrNull(Money? money) => money == null || money.isZero;
}

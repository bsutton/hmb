import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

extension MoneyEx on Money {
  static Money get zero => Money.fromInt(0, isoCode: 'AUD');

  static Money tryParse(String? amount) =>
      Money.tryParse(Strings.orElseOnBlank(amount, '0'), isoCode: 'AUD') ??
      zero;

  static Money fromInt(int? amount) =>
      Money.fromInt(amount ?? 0, isoCode: 'AUD');
}

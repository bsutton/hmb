import 'package:money2/money2.dart';

import '../../../util/dart/money_ex.dart';

enum ReceiptTotalBasis { includingTax, excludingTax }

class ReceiptTaxTotals {
  final Money excluding;
  final Money tax;
  final Money including;

  const ReceiptTaxTotals({
    required this.excluding,
    required this.tax,
    required this.including,
  });
}

class ReceiptTaxCalculator {
  const ReceiptTaxCalculator._();

  static ReceiptTaxTotals fromRate({
    required ReceiptTotalBasis basis,
    required Money total,
    required int rateBasisPoints,
  }) {
    if (basis == ReceiptTotalBasis.includingTax) {
      final tax = taxFromInclusive(total, rateBasisPoints);
      return ReceiptTaxTotals(
        excluding: total - tax,
        tax: tax,
        including: total,
      );
    }

    final tax = taxFromExclusive(total, rateBasisPoints);
    return ReceiptTaxTotals(excluding: total, tax: tax, including: total + tax);
  }

  static ReceiptTaxTotals fromDirectTax({
    required ReceiptTotalBasis basis,
    required Money total,
    required Money tax,
  }) => basis == ReceiptTotalBasis.includingTax
      ? ReceiptTaxTotals(excluding: total - tax, tax: tax, including: total)
      : ReceiptTaxTotals(excluding: total, tax: tax, including: total + tax);

  /// Balances extracted values even when OCR omits a value or returns an
  /// inconsistent exclusive total. Inclusive total and tax take precedence
  /// when both are present because they can be verified directly on receipts.
  static ReceiptTaxTotals balanceExtraction({
    required int excludingMinorUnits,
    required int taxMinorUnits,
    required int includingMinorUnits,
    required int fallbackRateBasisPoints,
  }) {
    final excluding = MoneyEx.fromInt(excludingMinorUnits);
    final tax = MoneyEx.fromInt(taxMinorUnits);
    final including = MoneyEx.fromInt(includingMinorUnits);

    if (!including.isZero && !tax.isZero) {
      return fromDirectTax(
        basis: ReceiptTotalBasis.includingTax,
        total: including,
        tax: tax,
      );
    }
    if (!excluding.isZero && !tax.isZero) {
      return fromDirectTax(
        basis: ReceiptTotalBasis.excludingTax,
        total: excluding,
        tax: tax,
      );
    }
    if (!including.isZero && !excluding.isZero) {
      return ReceiptTaxTotals(
        excluding: excluding,
        tax: including - excluding,
        including: including,
      );
    }
    if (!including.isZero) {
      return fromRate(
        basis: ReceiptTotalBasis.includingTax,
        total: including,
        rateBasisPoints: fallbackRateBasisPoints,
      );
    }
    if (!excluding.isZero) {
      return fromRate(
        basis: ReceiptTotalBasis.excludingTax,
        total: excluding,
        rateBasisPoints: fallbackRateBasisPoints,
      );
    }
    return ReceiptTaxTotals(excluding: MoneyEx.zero, tax: tax, including: tax);
  }

  static Money taxFromInclusive(Money total, int rateBasisPoints) {
    if (total.isZero || rateBasisPoints == 0) {
      return MoneyEx.zero;
    }
    final minorUnits = total.minorUnits.toInt();
    final sign = minorUnits.isNegative ? -1 : 1;
    final absoluteTotal = minorUnits.abs();
    final divisor = 10000 + rateBasisPoints;
    return MoneyEx.fromInt(
      sign * ((absoluteTotal * rateBasisPoints + divisor ~/ 2) ~/ divisor),
    );
  }

  static Money taxFromExclusive(Money total, int rateBasisPoints) {
    if (total.isZero || rateBasisPoints == 0) {
      return MoneyEx.zero;
    }
    final minorUnits = total.minorUnits.toInt();
    final sign = minorUnits.isNegative ? -1 : 1;
    final absoluteTotal = minorUnits.abs();
    return MoneyEx.fromInt(
      sign * ((absoluteTotal * rateBasisPoints + 5000) ~/ 10000),
    );
  }
}

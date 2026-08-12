import 'package:hmb/ui/crud/receipt/receipt_tax_calculator.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

void main() {
  group('ReceiptTaxCalculator', () {
    test('calculates exclusive total from a tax-inclusive edit', () {
      final totals = ReceiptTaxCalculator.fromRate(
        basis: ReceiptTotalBasis.includingTax,
        total: MoneyEx.dollars(110),
        rateBasisPoints: 1000,
      );

      expect(totals.excluding, MoneyEx.dollars(100));
      expect(totals.tax, MoneyEx.dollars(10));
    });

    test('calculates inclusive total from a tax-exclusive edit', () {
      final totals = ReceiptTaxCalculator.fromRate(
        basis: ReceiptTotalBasis.excludingTax,
        total: MoneyEx.dollars(100),
        rateBasisPoints: 1000,
      );

      expect(totals.tax, MoneyEx.dollars(10));
      expect(totals.including, MoneyEx.dollars(110));
    });

    test('supports direct tax entry from either total', () {
      final fromExclusive = ReceiptTaxCalculator.fromDirectTax(
        basis: ReceiptTotalBasis.excludingTax,
        total: MoneyEx.dollars(80),
        tax: MoneyEx.dollars(7),
      );
      final fromInclusive = ReceiptTaxCalculator.fromDirectTax(
        basis: ReceiptTotalBasis.includingTax,
        total: MoneyEx.dollars(87),
        tax: MoneyEx.dollars(7),
      );

      expect(fromExclusive.including, MoneyEx.dollars(87));
      expect(fromInclusive.excluding, MoneyEx.dollars(80));
    });

    test('preserves signs for returns', () {
      final totals = ReceiptTaxCalculator.fromRate(
        basis: ReceiptTotalBasis.excludingTax,
        total: MoneyEx.dollars(-100),
        rateBasisPoints: 1000,
      );

      expect(totals.tax, MoneyEx.dollars(-10));
      expect(totals.including, MoneyEx.dollars(-110));
    });

    test('fills missing extraction totals using the configured rate', () {
      final fromInclusive = ReceiptTaxCalculator.balanceExtraction(
        excludingMinorUnits: 0,
        taxMinorUnits: 0,
        includingMinorUnits: 11000,
        fallbackRateBasisPoints: 1000,
      );
      final fromExclusive = ReceiptTaxCalculator.balanceExtraction(
        excludingMinorUnits: 10000,
        taxMinorUnits: 0,
        includingMinorUnits: 0,
        fallbackRateBasisPoints: 1000,
      );

      expect(fromInclusive.excluding, MoneyEx.dollars(100));
      expect(fromInclusive.tax, MoneyEx.dollars(10));
      expect(fromExclusive.tax, MoneyEx.dollars(10));
      expect(fromExclusive.including, MoneyEx.dollars(110));
    });

    test('corrects an inconsistent extracted exclusive total', () {
      final totals = ReceiptTaxCalculator.balanceExtraction(
        excludingMinorUnits: 9500,
        taxMinorUnits: 1000,
        includingMinorUnits: 11000,
        fallbackRateBasisPoints: 1000,
      );

      expect(totals.excluding, MoneyEx.dollars(100));
      expect(totals.tax, MoneyEx.dollars(10));
      expect(totals.including, MoneyEx.dollars(110));
    });
  });
}

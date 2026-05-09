import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('seeded tax schemes and default tax codes are available', () async {
    final auScheme = await DaoTaxScheme().getByCode('au_gst');
    final ukScheme = await DaoTaxScheme().getByCountryCode('GB');
    final usScheme = await DaoTaxScheme().getByCode('us_sales_tax');

    expect(auScheme, isNotNull);
    expect(auScheme!.taxLabel, 'GST');
    expect(ukScheme?.taxLabel, 'VAT');
    expect(usScheme?.supportsJurisdictionReporting, isTrue);
    expect(usScheme?.supportsInputCredits, isFalse);

    final auDefaultSales = await DaoTaxCode().getDefaultSalesCode(
      auScheme.id,
      effectiveOn: DateTime(2026),
    );
    expect(auDefaultSales, isNotNull);
    expect(auDefaultSales!.code, 'gst_10');
    expect(auDefaultSales.rateBasisPoints, 1000);
    expect(auDefaultSales.taxTreatment, TaxTreatment.taxable);
  });

  test('tax code lookup respects effective date ranges', () async {
    final scheme = await DaoTaxScheme().getByCode('custom');
    expect(scheme, isNotNull);

    final oldCode = TaxCode.forInsert(
      taxSchemeId: scheme!.id,
      code: 'custom_rate',
      displayName: 'Custom old rate',
      rateBasisPoints: 500,
      taxTreatment: TaxTreatment.taxable,
      effectiveFrom: DateTime(2024),
      effectiveTo: DateTime(2024, 12, 31),
      isDefaultSales: true,
      isDefaultPurchase: false,
    );
    final newCode = TaxCode.forInsert(
      taxSchemeId: scheme.id,
      code: 'custom_rate',
      displayName: 'Custom new rate',
      rateBasisPoints: 750,
      taxTreatment: TaxTreatment.taxable,
      effectiveFrom: DateTime(2025),
      isDefaultSales: true,
      isDefaultPurchase: false,
    );

    await DaoTaxCode().insert(oldCode);
    await DaoTaxCode().insert(newCode);

    final code2024 = await DaoTaxCode().getDefaultSalesCode(
      scheme.id,
      effectiveOn: DateTime(2024, 6),
    );
    final code2025 = await DaoTaxCode().getDefaultSalesCode(
      scheme.id,
      effectiveOn: DateTime(2025, 6),
    );

    expect(code2024?.rateBasisPoints, 500);
    expect(code2025?.rateBasisPoints, 750);
  });
}

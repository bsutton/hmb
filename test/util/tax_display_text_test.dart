/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 GPL terms per repo license.
*/

import 'package:hmb/util/dart/app_settings.dart';
import 'package:hmb/util/dart/tax_display_text.dart';
import 'package:test/test.dart';

import 'settings_test_helper.dart';

void main() {
  setUpAll(prepareSettingsTest);

  setUp(() async {
    await resetSettingsForTest();
  });

  group('AppSettings tax values', () {
    test('defaults are empty/none', () async {
      expect(await AppSettings.getTaxDisplayMode(), TaxDisplayMode.none);
      expect(await AppSettings.getTaxLabel(), isEmpty);
      expect(await AppSettings.getTaxRatePercentText(), isEmpty);
      expect(await AppSettings.getTaxSchemeCode(), isEmpty);
    });

    test('round trips and trims persisted values', () async {
      await AppSettings.setTaxDisplayMode(TaxDisplayMode.inclusive);
      await AppSettings.setTaxSchemeCode('au_gst');
      await AppSettings.setTaxLabel('  GST  ');
      await AppSettings.setTaxRatePercentText(' 10 ');

      expect(await AppSettings.getTaxDisplayMode(), TaxDisplayMode.inclusive);
      expect(await AppSettings.getTaxSchemeCode(), 'au_gst');
      expect(await AppSettings.getTaxLabel(), 'GST');
      expect(await AppSettings.getTaxRatePercentText(), '10');
    });
  });

  group('buildPdfTaxDisplayText', () {
    test('returns null when mode is hidden', () async {
      await AppSettings.setTaxDisplayMode(TaxDisplayMode.none);
      await AppSettings.setTaxLabel('GST');
      await AppSettings.setTaxRatePercentText('10');

      expect(await buildPdfTaxDisplayText(), isNull);
    });

    test('returns null when label is blank', () async {
      await AppSettings.setTaxDisplayMode(TaxDisplayMode.inclusive);
      await AppSettings.setTaxLabel('   ');
      await AppSettings.setTaxRatePercentText('10');

      expect(await buildPdfTaxDisplayText(), isNull);
    });

    test('inclusive output includes label and optional rate', () async {
      await AppSettings.setTaxDisplayMode(TaxDisplayMode.inclusive);
      await AppSettings.setTaxLabel('GST');
      await AppSettings.setTaxRatePercentText('10');

      expect(await buildPdfTaxDisplayText(), 'All prices include GST (10%)');
    });

    test('exclusive output omits empty rate', () async {
      await AppSettings.setTaxDisplayMode(TaxDisplayMode.exclusive);
      await AppSettings.setTaxLabel('VAT');
      await AppSettings.setTaxRatePercentText('   ');

      expect(await buildPdfTaxDisplayText(), 'All prices exclude VAT');
    });
  });
}

/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 GPL terms per repo license.
*/

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/util/dart/app_settings.dart';
import 'package:hmb/util/dart/tax_display_text.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakePathProvider = _FakePathProvider();
  PathProviderPlatform.instance = fakePathProvider;

  final settingsPath = p.join(fakePathProvider.docPath, 'settings');

  Future<void> resetSettings() async {
    final file = File(settingsPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  setUp(() async {
    await resetSettings();
  });

  group('AppSettings tax values', () {
    test('defaults are empty/none', () async {
      expect(await AppSettings.getTaxDisplayMode(), TaxDisplayMode.none);
      expect(await AppSettings.getTaxLabel(), isEmpty);
      expect(await AppSettings.getTaxRatePercentText(), isEmpty);
    });

    test('round trips and trims persisted values', () async {
      await AppSettings.setTaxDisplayMode(TaxDisplayMode.inclusive);
      await AppSettings.setTaxLabel('  GST  ');
      await AppSettings.setTaxRatePercentText(' 10 ');

      expect(await AppSettings.getTaxDisplayMode(), TaxDisplayMode.inclusive);
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

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String docPath = Directory.systemTemp
      .createTempSync('hmb_tax_doc_')
      .path;
  final String tempPath = Directory.systemTemp
      .createTempSync('hmb_tax_tmp_')
      .path;

  @override
  Future<String?> getApplicationDocumentsPath() async => docPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

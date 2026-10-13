import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/api/product_catalog/catalog_preferences.dart';
import 'package:hmb/util/dart/app_settings.dart';

import '../../util/settings_test_helper.dart';

void main() {
  setUpAll(prepareSettingsTest);
  setUp(resetSettingsForTest);

  test(
    'default store survives a new preference instance without losing settings',
    () async {
      await AppSettings.setPhotoCacheMaxMb(123);
      expect(await const SavedCatalogPreferences().readDefaultStore(), isNull);
      await const SavedCatalogPreferences().saveDefaultStore('demo-east');
      expect(
        await const SavedCatalogPreferences().readDefaultStore(),
        'demo-east',
      );
      expect(await AppSettings.getPhotoCacheMaxMb(), 123);
    },
  );
}

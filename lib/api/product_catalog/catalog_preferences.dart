import 'package:settings_yaml/settings_yaml.dart';

import '../../util/dart/paths.dart';

abstract interface class CatalogPreferences {
  Future<String?> readDefaultStore();
  Future<void> saveDefaultStore(String id);
}

/// Stores only a demo store ID; never an address, coordinates or API data.
class SavedCatalogPreferences implements CatalogPreferences {
  const SavedCatalogPreferences();
  static const _key = 'bunningsDemoDefaultStore';

  @override
  Future<String?> readDefaultStore() async {
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    return settings[_key] as String?;
  }

  @override
  Future<void> saveDefaultStore(String id) async {
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    settings[_key] = id;
    await settings.save();
  }
}

/// Used by the standalone preview and tests so they cannot touch app settings.
class MemoryCatalogPreferences implements CatalogPreferences {
  String? defaultStore;

  @override
  Future<String?> readDefaultStore() async => defaultStore;

  @override
  Future<void> saveDefaultStore(String id) async => defaultStore = id;
}

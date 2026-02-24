import 'package:settings_yaml/settings_yaml.dart';

import '../../../../util/flutter/paths_flutter.dart';

class GoogleDriveFolderStore {
  static const _hmbFolderKey = 'GoogleDrive.hmbFolderId';
  static const _backupFolderKey = 'GoogleDrive.backupFolderId';
  static const _photoFolderKey = 'GoogleDrive.photoFolderId';
  static const _hmbDebugFolderKey = 'GoogleDrive.debug.hmbFolderId';
  static const _backupDebugFolderKey = 'GoogleDrive.debug.backupFolderId';
  static const _photoDebugFolderKey = 'GoogleDrive.debug.photoFolderId';

  Future<String?> getHmbFolderId({required bool debug}) =>
      _get(_keyFor(_hmbFolderKey, _hmbDebugFolderKey, debug));

  Future<String?> getBackupFolderId({required bool debug}) =>
      _get(_keyFor(_backupFolderKey, _backupDebugFolderKey, debug));

  Future<String?> getPhotoFolderId({required bool debug}) =>
      _get(_keyFor(_photoFolderKey, _photoDebugFolderKey, debug));

  Future<void> setHmbFolderId(String id, {required bool debug}) =>
      _set(_keyFor(_hmbFolderKey, _hmbDebugFolderKey, debug), id);

  Future<void> setBackupFolderId(String id, {required bool debug}) =>
      _set(_keyFor(_backupFolderKey, _backupDebugFolderKey, debug), id);

  Future<void> setPhotoFolderId(String id, {required bool debug}) =>
      _set(_keyFor(_photoFolderKey, _photoDebugFolderKey, debug), id);

  Future<void> clearAll() async {
    await _remove(_hmbFolderKey);
    await _remove(_backupFolderKey);
    await _remove(_photoFolderKey);
    await _remove(_hmbDebugFolderKey);
    await _remove(_backupDebugFolderKey);
    await _remove(_photoDebugFolderKey);
  }

  String _keyFor(String normalKey, String debugKey, bool debug) =>
      debug ? debugKey : normalKey;

  Future<String?> _get(String key) async {
    try {
      final settings = SettingsYaml.load(
        pathToSettings: await getSettingsPath(),
      );
      final value = settings[key]?.toString();
      if (value == null || value.isEmpty) {
        return null;
      }
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<void> _set(String key, String value) async {
    try {
      final settings = SettingsYaml.load(
        pathToSettings: await getSettingsPath(),
      );
      settings[key] = value;
      await settings.save();
    } catch (_) {
      // Ignore persistence failures in contexts like worker isolates.
    }
  }

  Future<void> _remove(String key) async {
    try {
      final settings = SettingsYaml.load(
        pathToSettings: await getSettingsPath(),
      );
      settings[key] = '';
      await settings.save();
    } catch (_) {
      // Ignore persistence failures in contexts like worker isolates.
    }
  }
}

/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:sqflite_common/sqlite_api.dart';
import 'package:strings/strings.dart';

import '../entity/system.dart';
import 'system_secret_backend.dart';
import 'system_secret_backend_stub.dart'
    if (dart.library.ui) 'system_secret_backend_flutter.dart';

class SystemSecretStore {
  final SystemSecretBackend _backend;

  SystemSecretStore({SystemSecretBackend? backend})
    : _backend = backend ?? createSystemSecretBackend();

  static const _xeroClientSecretKey = 'system.xero_client_secret';
  static const _chatGptAccessTokenKey = 'system.chatgpt_access_token';
  static const _chatGptRefreshTokenKey = 'system.chatgpt_refresh_token';
  static const _openAiApiKey = 'system.openai_api_key';
  static const _ihserverTokenKey = 'system.ihserver_token';

  Future<void> hydrate(System system) async {
    system
      ..xeroClientSecret = await _read(
        _xeroClientSecretKey,
        fallback: system.xeroClientSecret,
      )
      ..chatgptAccessToken = await _read(
        _chatGptAccessTokenKey,
        fallback: system.chatgptAccessToken,
      )
      ..chatgptRefreshToken = await _read(
        _chatGptRefreshTokenKey,
        fallback: system.chatgptRefreshToken,
      )
      ..openaiApiKey = await _read(_openAiApiKey, fallback: system.openaiApiKey)
      ..ihserverToken = await _read(
        _ihserverTokenKey,
        fallback: system.ihserverToken,
      );
  }

  Future<bool> migrateFromDb(System system) async {
    final secrets = <String, String?>{
      _xeroClientSecretKey: system.xeroClientSecret,
      _chatGptAccessTokenKey: system.chatgptAccessToken,
      _chatGptRefreshTokenKey: system.chatgptRefreshToken,
      _openAiApiKey: system.openaiApiKey,
      _ihserverTokenKey: system.ihserverToken,
    };

    var hadLegacySecrets = false;

    for (final entry in secrets.entries) {
      final legacyValue = entry.value;
      if (Strings.isBlank(legacyValue)) {
        continue;
      }
      hadLegacySecrets = true;
      final migrated = await _migrate(
        entry.key,
        legacyValue: legacyValue!.trim(),
      );
      if (!migrated) {
        return false;
      }
    }

    return hadLegacySecrets;
  }

  Future<bool> persist(System system) async =>
      await _write(_xeroClientSecretKey, system.xeroClientSecret) &&
      await _write(_chatGptAccessTokenKey, system.chatgptAccessToken) &&
      await _write(_chatGptRefreshTokenKey, system.chatgptRefreshToken) &&
      await _write(_openAiApiKey, system.openaiApiKey) &&
      await _write(_ihserverTokenKey, system.ihserverToken);

  Future<void> clearLegacyDbCopies({
    required DatabaseExecutor executor,
    required int systemId,
  }) async {
    await executor.update(
      'system',
      {
        'xero_client_secret': null,
        'chatgpt_access_token': null,
        'chatgpt_refresh_token': null,
        'openai_api_key': null,
        'ihserver_token': null,
      },
      where: 'id = ?',
      whereArgs: [systemId],
    );
  }

  Future<String?> _read(String key, {String? fallback}) async {
    try {
      final value = await _backend.read(key);
      if (Strings.isBlank(value)) {
        return fallback;
      }
      return value!.trim();
    } catch (_) {
      return fallback;
    }
  }

  Future<bool> _migrate(String key, {required String legacyValue}) async {
    try {
      final existing = await _backend.read(key);
      if (Strings.isBlank(existing)) {
        await _backend.write(key, legacyValue);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _write(String key, String? value) async {
    try {
      if (Strings.isBlank(value)) {
        await _backend.delete(key);
      } else {
        await _backend.write(key, value!.trim());
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

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

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:strings/strings.dart';

import '../entity/system.dart';

class SystemSecretStore {
  static const _storage = FlutterSecureStorage();

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
    var migrated = false;
    migrated |= await _migrate(
      _xeroClientSecretKey,
      legacyValue: system.xeroClientSecret,
    );
    migrated |= await _migrate(
      _chatGptAccessTokenKey,
      legacyValue: system.chatgptAccessToken,
    );
    migrated |= await _migrate(
      _chatGptRefreshTokenKey,
      legacyValue: system.chatgptRefreshToken,
    );
    migrated |= await _migrate(_openAiApiKey, legacyValue: system.openaiApiKey);
    migrated |= await _migrate(
      _ihserverTokenKey,
      legacyValue: system.ihserverToken,
    );
    return migrated;
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
      final value = await _storage.read(key: key);
      if (Strings.isBlank(value)) {
        return fallback;
      }
      return value!.trim();
    } catch (_) {
      return fallback;
    }
  }

  Future<bool> _migrate(String key, {String? legacyValue}) async {
    if (Strings.isBlank(legacyValue)) {
      return false;
    }
    try {
      final existing = await _storage.read(key: key);
      if (Strings.isBlank(existing)) {
        await _storage.write(key: key, value: legacyValue!.trim());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _write(String key, String? value) async {
    try {
      if (Strings.isBlank(value)) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value!.trim());
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

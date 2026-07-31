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
import '../entity/system_credentials.dart';
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
  static const _googleMapsApiKey = 'system.google_maps_api_key';
  static const _ihserverTokenKey = 'system.ihserver_token';
  static const _smtpPasswordKey = 'system.smtp_password';

  Future<XeroCredentials> readXeroCredentials() async =>
      XeroCredentials(clientSecret: await _read(_xeroClientSecretKey));

  Future<void> writeXeroCredentials(XeroCredentials credentials) async {
    await _writeOrThrow(_xeroClientSecretKey, credentials.clientSecret);
  }

  Future<ChatGptCredentials> readChatGptCredentials() async {
    final values = await Future.wait([
      _read(_chatGptAccessTokenKey),
      _read(_chatGptRefreshTokenKey),
    ]);
    return ChatGptCredentials(accessToken: values[0], refreshToken: values[1]);
  }

  Future<void> writeChatGptCredentials(ChatGptCredentials credentials) async {
    await _writeOrThrow(_chatGptAccessTokenKey, credentials.accessToken);
    await _writeOrThrow(_chatGptRefreshTokenKey, credentials.refreshToken);
  }

  Future<OpenAiCredentials> readOpenAiCredentials() async =>
      OpenAiCredentials(apiKey: await _read(_openAiApiKey));

  Future<void> writeOpenAiCredentials(OpenAiCredentials credentials) async {
    await _writeOrThrow(_openAiApiKey, credentials.apiKey);
  }

  Future<GoogleMapsCredentials> readGoogleMapsCredentials() async =>
      GoogleMapsCredentials(apiKey: await _read(_googleMapsApiKey));

  Future<void> writeGoogleMapsCredentials(
    GoogleMapsCredentials credentials,
  ) async {
    await _writeOrThrow(_googleMapsApiKey, credentials.apiKey);
  }

  Future<IhserverCredentials> readIhserverCredentials() async =>
      IhserverCredentials(token: await _read(_ihserverTokenKey));

  Future<void> writeIhserverCredentials(IhserverCredentials credentials) async {
    await _writeOrThrow(_ihserverTokenKey, credentials.token);
  }

  Future<SmtpCredentials> readSmtpCredentials() async =>
      SmtpCredentials(password: await _read(_smtpPasswordKey));

  Future<void> writeSmtpCredentials(SmtpCredentials credentials) async {
    await _writeOrThrow(_smtpPasswordKey, credentials.password);
  }

  Future<bool> migrateFromDb(System system) async {
    final secrets = <String, String?>{
      _xeroClientSecretKey: system.xeroClientSecret,
      _chatGptAccessTokenKey: system.chatgptAccessToken,
      _chatGptRefreshTokenKey: system.chatgptRefreshToken,
      _openAiApiKey: system.openaiApiKey,
      _googleMapsApiKey: system.googleMapsApiKey,
      _ihserverTokenKey: system.ihserverToken,
      _smtpPasswordKey: system.smtpPassword,
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
      await _write(_googleMapsApiKey, system.googleMapsApiKey) &&
      await _write(_ihserverTokenKey, system.ihserverToken) &&
      await _write(_smtpPasswordKey, system.smtpPassword);

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

  Future<String?> _read(String key) async {
    try {
      final value = await _backend.read(key);
      if (Strings.isBlank(value)) {
        return null;
      }
      return value!.trim();
    } catch (_) {
      return null;
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

  Future<void> _writeOrThrow(String key, String? value) async {
    if (!await _write(key, value)) {
      throw StateError('Unable to update encrypted system credentials.');
    }
  }
}

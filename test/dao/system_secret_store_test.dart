import 'package:hmb/dao/system_secret_backend.dart';
import 'package:hmb/dao/system_secret_store.dart';
import 'package:hmb/entity/system_credentials.dart';
import 'package:test/test.dart';

class _FakeSystemSecretBackend implements SystemSecretBackend {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test('reads and writes integration-specific credentials', () async {
    final store = SystemSecretStore(backend: _FakeSystemSecretBackend());

    await store.writeXeroCredentials(
      const XeroCredentials(clientSecret: 'xero'),
    );
    await store.writeChatGptCredentials(
      const ChatGptCredentials(accessToken: 'access', refreshToken: 'refresh'),
    );
    await store.writeOpenAiCredentials(
      const OpenAiCredentials(apiKey: 'openai'),
    );
    await store.writeGoogleMapsCredentials(
      const GoogleMapsCredentials(apiKey: 'maps'),
    );
    await store.writeIhserverCredentials(
      const IhserverCredentials(token: 'ihserver'),
    );
    await store.writeSmtpCredentials(const SmtpCredentials(password: 'smtp'));

    expect((await store.readXeroCredentials()).clientSecret, 'xero');
    final chatGpt = await store.readChatGptCredentials();
    expect(chatGpt.accessToken, 'access');
    expect(chatGpt.refreshToken, 'refresh');
    expect((await store.readOpenAiCredentials()).apiKey, 'openai');
    expect((await store.readGoogleMapsCredentials()).apiKey, 'maps');
    expect((await store.readIhserverCredentials()).token, 'ihserver');
    expect((await store.readSmtpCredentials()).password, 'smtp');
  });

  test('blank credentials delete the secure value', () async {
    final backend = _FakeSystemSecretBackend();
    final store = SystemSecretStore(backend: backend);
    await store.writeOpenAiCredentials(
      const OpenAiCredentials(apiKey: 'openai'),
    );

    await store.writeOpenAiCredentials(const OpenAiCredentials(apiKey: null));

    expect((await store.readOpenAiCredentials()).apiKey, isNull);
  });
}

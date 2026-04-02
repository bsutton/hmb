import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/system_secret_backend.dart';
import 'package:hmb/dao/system_secret_store.dart';
import 'package:hmb/database/versions/post_upgrade/post_upgrade_168.dart';

import 'db_utility_test_helper.dart';

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
  test('v168 migrates legacy system secrets into secure storage', () async {
    final db = await setupTestDb();

    try {
      await db.update(
        'system',
        {
          'xero_client_secret': 'xero-secret',
          'chatgpt_access_token': 'chatgpt-access',
          'chatgpt_refresh_token': 'chatgpt-refresh',
          'openai_api_key': 'openai-key',
          'ihserver_token': 'ihserver-token',
        },
        where: 'id = ?',
        whereArgs: [1],
      );

      final backend = _FakeSystemSecretBackend();
      await postv168Upgrade(
        db,
        secretStore: SystemSecretStore(backend: backend),
      );

      final rows = await db.query('system', where: 'id = ?', whereArgs: [1]);
      final row = rows.single;

      expect(backend.values['system.xero_client_secret'], 'xero-secret');
      expect(backend.values['system.chatgpt_access_token'], 'chatgpt-access');
      expect(backend.values['system.chatgpt_refresh_token'], 'chatgpt-refresh');
      expect(backend.values['system.openai_api_key'], 'openai-key');
      expect(backend.values['system.ihserver_token'], 'ihserver-token');

      expect(row['xero_client_secret'], isNull);
      expect(row['chatgpt_access_token'], isNull);
      expect(row['chatgpt_refresh_token'], isNull);
      expect(row['openai_api_key'], isNull);
      expect(row['ihserver_token'], isNull);
    } finally {
      await tearDownTestDb();
    }
  });
}

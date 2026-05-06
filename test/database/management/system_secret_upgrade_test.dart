import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/system_secret_backend.dart';
import 'package:hmb/dao/system_secret_store.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/database/versions/implementations/project_script_source.dart';
import 'package:hmb/database/versions/post_upgrade/post_upgrade_168.dart';
import 'package:sqflite_common/sqlite_api.dart';

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
      await _ensureLegacySecretColumns(db);
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

  test(
    'v179 drops legacy system secret columns after v168 migration',
    () async {
      final db = await setupTestDb();

      try {
        await _ensureLegacySecretColumns(db);
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

        final source = ProjectScriptSource();
        final sql = await source.loadSQL('assets/sql/upgrade_scripts/v179.sql');
        final statements = await parseSqlFile(sql);
        for (final statement in statements) {
          await db.execute(statement);
        }

        final columns = await db.rawQuery('PRAGMA table_info(system)');
        final names = {for (final row in columns) row['name'] as String? ?? ''};

        expect(names.contains('xero_client_secret'), isFalse);
        expect(names.contains('chatgpt_access_token'), isFalse);
        expect(names.contains('chatgpt_refresh_token'), isFalse);
        expect(names.contains('openai_api_key'), isFalse);
        expect(names.contains('ihserver_token'), isFalse);
        expect(backend.values['system.xero_client_secret'], 'xero-secret');
        expect(backend.values['system.openai_api_key'], 'openai-key');
      } finally {
        await tearDownTestDb();
      }
    },
  );
}

Future<void> _ensureLegacySecretColumns(DatabaseExecutor db) async {
  final columns = await db.rawQuery('PRAGMA table_info(system)');
  final names = {for (final row in columns) row['name'] as String? ?? ''};
  for (final name in [
    'xero_client_secret',
    'chatgpt_access_token',
    'chatgpt_refresh_token',
    'openai_api_key',
    'ihserver_token',
  ]) {
    if (!names.contains(name)) {
      await db.execute('ALTER TABLE system ADD COLUMN $name TEXT');
    }
  }
}

import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/system_secret_backend.dart';
import 'package:hmb/dao/system_secret_store.dart';
import 'package:hmb/entity/system.dart';
import 'package:hmb/entity/system_credentials.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';
import '../util/settings_test_helper.dart';

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
  setUpAll(prepareSettingsTest);

  setUp(() async {
    await resetSettingsForTest();
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('system default profit margin persists', () async {
    final daoSystem = DaoSystem();
    final system = await daoSystem.getForUpdate();

    system.defaultProfitMargin = Percentage.fromInt(17500, decimalDigits: 3);
    await daoSystem.updateConfiguration(system);

    final updated = await daoSystem.getForUpdate();
    expect(
      updated.defaultProfitMargin,
      Percentage.fromInt(17500, decimalDigits: 3),
    );
  });

  test('system default profit margin defaults to 20 percent', () async {
    final margin = await DaoSystem().getDefaultProfitMargin();
    expect(margin, Percentage.fromInt(20000, decimalDigits: 3));
  });

  test('system default sim slot persists', () async {
    final daoSystem = DaoSystem();
    final system = await daoSystem.getForUpdate();

    system.simCardNo = 2;
    await daoSystem.updateConfiguration(system);

    final updated = await daoSystem.getForUpdate();
    expect(updated.simCardNo, 2);
  });

  test('get returns an immutable configuration snapshot', () async {
    final daoSystem = DaoSystem();
    final configuration = await daoSystem.get();
    final mutable = await daoSystem.getForUpdate();
    final originalBusinessName = configuration.businessName;
    mutable.businessName = 'Changed after snapshot';

    expect(configuration, isA<SystemConfiguration>());
    expect(configuration.id, 1);
    expect(configuration.businessName, originalBusinessName);
  });

  test('configuration updates preserve encrypted credentials', () async {
    final backend = _FakeSystemSecretBackend();
    final daoSystem = DaoSystem(
      secretStore: SystemSecretStore(backend: backend),
    );
    await daoSystem.updateOpenAiCredentials(
      const OpenAiCredentials(apiKey: 'secret-key'),
    );

    final system = await daoSystem.getForUpdate();
    system.simCardNo = 2;
    await daoSystem.updateConfiguration(system);

    final credentials = await daoSystem.getOpenAiCredentials();
    expect(credentials.apiKey, 'secret-key');
  });
}

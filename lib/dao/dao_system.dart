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

import 'package:dlibphonenumber/enums/phone_number_format.dart';
import 'package:dlibphonenumber/phone_number_util.dart';
import 'package:money2/money2.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:strings/strings.dart';

import '../entity/system.dart';
import '../entity/system_credentials.dart';
import '../util/dart/app_settings.dart';
import '../util/dart/exceptions.dart' as hmb;
import 'dao.dart';
import 'system_secret_store.dart';

class DaoSystem extends Dao<System> {
  static const tableName = 'system';
  static final defaultProfitMargin = Percentage.fromInt(
    20000,
    decimalDigits: 3,
  );
  final SystemSecretStore _secretStore;

  DaoSystem({SystemSecretStore? secretStore})
    : _secretStore = secretStore ?? SystemSecretStore(),
      super(tableName);
  Future<void> createTable(Database db, int version) async {}

  @override
  System fromMap(Map<String, dynamic> map) => System.fromMap(map);

  /// Returns an immutable snapshot containing no integration secrets.
  Future<SystemConfiguration> get([Transaction? transaction]) async =>
      SystemConfiguration.fromSystem(await getForUpdate(transaction));

  /// Loads a mutable system entity for a configuration update.
  ///
  /// The returned entity contains no integration secrets. Pass it to
  /// [updateConfiguration], which never writes secure storage.
  Future<System> getForUpdate([Transaction? transaction]) async =>
      (await getById(1, transaction))!;

  Future<XeroCredentials> getXeroCredentials() =>
      _secretStore.readXeroCredentials();

  Future<void> updateXeroCredentials(XeroCredentials credentials) =>
      _secretStore.writeXeroCredentials(credentials);

  Future<ChatGptCredentials> getChatGptCredentials() =>
      _secretStore.readChatGptCredentials();

  Future<void> updateChatGptCredentials(ChatGptCredentials credentials) =>
      _secretStore.writeChatGptCredentials(credentials);

  Future<OpenAiCredentials> getOpenAiCredentials() =>
      _secretStore.readOpenAiCredentials();

  Future<void> updateOpenAiCredentials(OpenAiCredentials credentials) =>
      _secretStore.writeOpenAiCredentials(credentials);

  Future<GoogleMapsCredentials> getGoogleMapsCredentials() =>
      _secretStore.readGoogleMapsCredentials();

  Future<void> updateGoogleMapsCredentials(GoogleMapsCredentials credentials) =>
      _secretStore.writeGoogleMapsCredentials(credentials);

  Future<IhserverCredentials> getIhserverCredentials() =>
      _secretStore.readIhserverCredentials();

  Future<void> updateIhserverCredentials(IhserverCredentials credentials) =>
      _secretStore.writeIhserverCredentials(credentials);

  Future<SmtpCredentials> getSmtpCredentials() =>
      _secretStore.readSmtpCredentials();

  Future<void> updateSmtpCredentials(SmtpCredentials credentials) =>
      _secretStore.writeSmtpCredentials(credentials);

  @override
  Future<int> insert(System entity, [Transaction? transaction]) async {
    await _secretStore.persist(entity);
    final executor = withinTransaction(transaction);

    final map = entity.toMap()..remove('id');

    final id = await executor.insert(tablename, map);
    if (id == 0) {
      throw hmb.DatabaseException('Insert for $System failed');
    }
    entity.id = id;
    Dao.notifier(this, id);
    return id;
  }

  @override
  @Deprecated('Use updateConfiguration so secret handling remains explicit.')
  Future<int> update(System entity, [Transaction? transaction]) =>
      updateConfiguration(entity, transaction);

  Future<int> updateConfiguration(
    System entity, [
    Transaction? transaction,
  ]) async {
    final executor = withinTransaction(transaction);

    entity.modifiedDate = DateTime.now();
    final map = entity.toMap();

    final count = await executor.update(
      tablename,
      map,
      where: 'id = ?',
      whereArgs: [entity.id],
    );
    assert(count == 1, 'We should always be only updating one entity');
    Dao.notifier(this, entity.id);
    return entity.id;
  }

  Future<Money> getHourlyRate() async {
    final system = await get();

    return system.defaultHourlyRate ?? Money.parse('100', isoCode: 'AUD');
  }

  Future<Percentage> getDefaultProfitMargin({
    SystemConfiguration? system,
  }) async {
    system ??= await get();
    if (system.defaultProfitMargin != null) {
      return system.defaultProfitMargin!;
    }

    final legacyMargin = Percentage.tryParse(
      await AppSettings.getDefaultProfitMarginText(),
    );
    return legacyMargin ?? defaultProfitMargin;
  }
}

Future<String> formatPhone(String? phone) async {
  if (Strings.isBlank(phone)) {
    return '';
  }
  final phoneUtil = PhoneNumberUtil.instance;

  final system = await DaoSystem().get();

  String formatted;

  try {
    final phoneNumber = phoneUtil.parse(phone, system.countryCode ?? 'AU');
    formatted = phoneUtil.format(phoneNumber, PhoneNumberFormat.national);
    // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    formatted = phone ?? '';
  }
  return formatted;
}

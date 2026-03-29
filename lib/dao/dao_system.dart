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
import '../util//dart/exceptions.dart' as hmb;
import 'dao.dart';
import 'system_secret_store.dart';

class DaoSystem extends Dao<System> {
  static const tableName = 'system';
  final _secretStore = SystemSecretStore();
  DaoSystem() : super(tableName);
  Future<void> createTable(Database db, int version) async {}

  @override
  System fromMap(Map<String, dynamic> map) => System.fromMap(map);

  Future<System> get([Transaction? transaction]) async {
    final system = (await getById(1, transaction))!;
    final migrated = await _secretStore.migrateFromDb(system);
    await _secretStore.hydrate(system);

    if (migrated) {
      await _secretStore.clearLegacyDbCopies(
        executor: withinTransaction(transaction),
        systemId: system.id,
      );
    }

    return system;
  }

  @override
  Future<int> insert(System entity, [Transaction? transaction]) async {
    final secretsPersisted = await _secretStore.persist(entity);
    final executor = withinTransaction(transaction);

    final map = entity.toMap()..remove('id');
    if (secretsPersisted) {
      _clearSecretFields(map);
    }

    final id = await executor.insert(tablename, map);
    if (id == 0) {
      throw hmb.DatabaseException('Insert for $System failed');
    }
    entity.id = id;
    Dao.notifier(this, id);
    return id;
  }

  @override
  Future<int> update(System entity, [Transaction? transaction]) async {
    final secretsPersisted = await _secretStore.persist(entity);
    final executor = withinTransaction(transaction);

    entity.modifiedDate = DateTime.now();
    final map = entity.toMap();
    if (secretsPersisted) {
      _clearSecretFields(map);
    }

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

  void _clearSecretFields(Map<String, dynamic> map) {
    map['xero_client_secret'] = null;
    map['chatgpt_access_token'] = null;
    map['chatgpt_refresh_token'] = null;
    map['openai_api_key'] = null;
    map['ihserver_token'] = null;
  }

  Future<Money> getHourlyRate() async {
    final system = await get();

    return system.defaultHourlyRate ?? Money.parse('100', isoCode: 'AUD');
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

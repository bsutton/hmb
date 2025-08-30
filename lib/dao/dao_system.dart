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
import 'dao.dart';

class DaoSystem extends Dao<System> {
  static const tableName = 'system';
  DaoSystem() : super(tableName);
  Future<void> createTable(Database db, int version) async {}

  @override
  System fromMap(Map<String, dynamic> map) => System.fromMap(map);

  Future<System> get() async => (await getById(1))!;

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

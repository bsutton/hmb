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

import '../entity/tax_scheme.dart';
import 'dao.dart';

class DaoTaxScheme extends Dao<TaxScheme> {
  static const tableName = 'tax_scheme';

  DaoTaxScheme() : super(tableName);

  @override
  TaxScheme fromMap(Map<String, dynamic> map) => TaxScheme.fromMap(map);

  Future<TaxScheme?> getByCode(String code) async {
    final rows = await withoutTransaction().query(
      tableName,
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    return rows.isEmpty ? null : fromMap(rows.first);
  }

  Future<TaxScheme?> getByCountryCode(String countryCode) async {
    final rows = await withoutTransaction().query(
      tableName,
      where: 'country_code = ?',
      whereArgs: [countryCode.toUpperCase()],
      orderBy: 'id ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : fromMap(rows.first);
  }
}

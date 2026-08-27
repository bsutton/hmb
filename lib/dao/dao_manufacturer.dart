// ignore_for_file: async_return_with_no_await

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

import '../entity/manufacturer.dart';
import 'dao.dart';
import 'dao_reference_guard.dart';

class DaoManufacturer extends Dao<Manufacturer> {
  static const tableName = 'manufacturer';

  DaoManufacturer() : super(tableName);

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    await DaoReferenceGuard.ensureNotReferenced(
      db: withinTransaction(transaction),
      entityName: 'Manufacturer',
      id: id,
      references: const [DaoReference('tool', 'manufacturerId', 'tools')],
    );
    return super.delete(id, transaction);
  }

  Future<List<Manufacturer>> getByFilter(String? filter) async {
    final db = withoutTransaction();

    if (Strings.isBlank(filter)) {
      return getAll(orderByClause: 'name');
    }
    final like = '''%$filter%''';
    return toList(
      await db.rawQuery(
        '''
select m.* 
from manufacturer m
where m.name like ?
or m.description like ?
order by m.name
''',
        [like, like],
      ),
    );
  }

  @override
  Manufacturer fromMap(Map<String, dynamic> map) => Manufacturer.fromMap(map);
}

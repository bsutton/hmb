/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:june/june.dart';
import 'package:strings/strings.dart';

import '../entity/supplier.dart';
import 'dao.dart';

class DaoSupplier extends Dao<Supplier> {
  Future<List<Supplier>> getByFilter(String? filter) async {
    final db = withoutTransaction();

    if (Strings.isBlank(filter)) {
      return getAll(orderByClause: 'name COLLATE NOCASE');
    }
    final like = '''%$filter%''';
    return toList(
      await db.rawQuery(
        '''
select s.* 
from supplier s
where s.name like ?
or s.description like ?
or s.service like ?
order by s.name COLLATE NOCASE
''',
        [like, like, like],
      ),
    );
  }

  @override
  Supplier fromMap(Map<String, dynamic> map) => Supplier.fromMap(map);

  @override
  String get tableName => 'supplier';
  @override
  JuneStateCreator get juneRefresher => SupplierState.new;
}

/// Used to notify the UI that the time entry has changed.
class SupplierState extends JuneState {
  SupplierState();
}

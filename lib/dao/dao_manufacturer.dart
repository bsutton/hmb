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

import '../entity/manufacturer.dart';
import 'dao.dart';

class DaoManufacturer extends Dao<Manufacturer> {
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

  @override
  String get tableName => 'manufacturer';
  @override
  JuneStateCreator get juneRefresher => ManufacturerState.new;
}

class ManufacturerState extends JuneState {
  ManufacturerState();
}

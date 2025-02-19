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
    final data = await db.rawQuery(
      '''
select m.* 
from manufacturer m
where m.name like ?
or m.description like ?
order by m.name
''',
      [like, like],
    );

    return toList(data);
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

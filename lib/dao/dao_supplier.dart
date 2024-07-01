import 'package:june/june.dart';
import 'package:strings/strings.dart';

import '../entity/supplier.dart';
import 'dao.dart';

class DaoSupplier extends Dao<Supplier> {
  Future<List<Supplier>> getByFilter(String? filter) async {
    final db = getDb();

    if (Strings.isBlank(filter)) {
      return getAll();
    }
    final like = '''%$filter%''';
    final data = await db.rawQuery('''
select s.* 
from supplier s
where s.name like ?
or s.description like ?
or s.service like ?
order by s.modifiedDate desc
''', [like, like, like]);

    return toList(data);
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

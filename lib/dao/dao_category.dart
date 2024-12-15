import 'package:june/june.dart';

import '../entity/category.dart';
import 'dao.dart';

    class DaoCategory extends Dao<Category> {

      Future<List<Category>> getByFilter(String? filter) async {

        if (filter == null || filter.isEmpty) {
          return getAll(orderByClause: 'name');
        }
        final like = '''%$filter%''';
        final data = await db.rawQuery('''
          SELECT * FROM category 
          WHERE name LIKE ? OR description LIKE ?
          ORDER BY name
        ''', [like, like]);

        return toList(data);
      }

  @override
  Category fromMap(Map<String, dynamic> map) => Category.fromMap(map);

  @override
  JuneStateCreator get juneRefresher => CategoryState.new;

  @override
  String get tableName => 'category';
}

/// Used to notify the UI that the quote has changed.
class CategoryState extends JuneState {
  CategoryState();
}

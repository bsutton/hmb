/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:june/june.dart';

import '../entity/category.dart';
import 'dao.dart';

class DaoCategory extends Dao<Category> {
  Future<List<Category>> getByFilter(String? filter) async {
    if (filter == null || filter.isEmpty) {
      return getAll(orderByClause: 'name');
    }
    final like = '''%$filter%''';
    return toList(
      await db.rawQuery(
        '''
          SELECT * FROM category 
          WHERE name LIKE ? OR description LIKE ?
          ORDER BY name
        ''',
        [like, like],
      ),
    );
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

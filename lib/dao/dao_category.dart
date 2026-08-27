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

import '../entity/category.dart';
import 'dao.dart';
import 'dao_reference_guard.dart';

class DaoCategory extends Dao<Category> {
  static const tableName = 'category';
  DaoCategory() : super(tableName);

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    await DaoReferenceGuard.ensureNotReferenced(
      db: withinTransaction(transaction),
      entityName: 'Category',
      id: id,
      references: const [DaoReference('tool', 'categoryId', 'tools')],
    );
    return super.delete(id, transaction);
  }

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
}

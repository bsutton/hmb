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

import '../entity/plaster_project.dart';
import 'dao.dart';

class DaoPlasterProject extends Dao<PlasterProject> {
  static const tableName = 'plaster_project';

  DaoPlasterProject() : super(tableName);

  @override
  PlasterProject fromMap(Map<String, dynamic> map) =>
      PlasterProject.fromMap(map);

  Future<List<PlasterProject>> getByFilter(String? filter) async {
    final db = withoutTransaction();
    final text = (filter ?? '').trim();
    if (text.isEmpty) {
      final rows = await db.query(
        tableName,
        orderBy: 'modified_date DESC, id DESC',
      );
      return toList(rows);
    }

    final rows = await db.query(
      tableName,
      where: 'name LIKE ?',
      whereArgs: ['%$text%'],
      orderBy: 'modified_date DESC, id DESC',
    );
    return toList(rows);
  }
}

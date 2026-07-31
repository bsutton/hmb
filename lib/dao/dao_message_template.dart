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

import '../entity/message_template.dart';
import 'dao.dart';

class DaoMessageTemplate extends Dao<MessageTemplate> {
  static const tableName = 'message_template';
  static const _selectClause = '''
    id,
    title,
    message,
    message_type,
    owner,
    enabled,
    ordinal,
    createdDate,
    modifiedDate
  ''';

  DaoMessageTemplate() : super(tableName);
  @override
  MessageTemplate fromMap(Map<String, dynamic> map) =>
      MessageTemplate.fromMap(map);

  Future<List<MessageTemplate>> getByFilter(String? filter) async {
    final db = withoutTransaction();

    const whereClause = '''
      title LIKE ?
    ''';

    if (filter == null || filter.isEmpty) {
      return toList(
        await db.rawQuery(
          'SELECT $_selectClause FROM message_template ORDER BY ordinal',
        ),
      );
    }

    return toList(
      await db.rawQuery(
        'SELECT $_selectClause FROM message_template WHERE $whereClause '
        'ORDER BY ordinal',
        ['%$filter%'],
      ),
    );
  }
}

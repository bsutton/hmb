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


import 'package:june/june.dart';

import '../entity/message_template.dart';
import 'dao.dart';

class DaoMessageTemplate extends Dao<MessageTemplate> {
  @override
  MessageTemplate fromMap(Map<String, dynamic> map) =>
      MessageTemplate.fromMap(map);

  @override
  String get tableName => 'message_template';

  Future<List<MessageTemplate>> getByFilter(String? filter) async {
    final db = withoutTransaction();

    if (filter == null || filter.isEmpty) {
      return getAll(orderByClause: 'modifiedDate desc');
    }

    return toList(
      await db.rawQuery(
        '''
      SELECT * FROM message_template 
      WHERE title LIKE ? 
      ORDER BY modifiedDate DESC
    ''',
        ['%$filter%'],
      ),
    );
  }

  @override
  JuneStateCreator get juneRefresher => MessageTemplateState.new;
}

/// Used to notify the UI that the message template has changed.
class MessageTemplateState extends JuneState {
  MessageTemplateState();
}

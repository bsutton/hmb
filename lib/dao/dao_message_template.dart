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

    final data = await db.rawQuery(
      '''
      SELECT * FROM message_template 
      WHERE title LIKE ? 
      ORDER BY modifiedDate DESC
    ''',
      ['%$filter%'],
    );

    return toList(data);
  }

  @override
  JuneStateCreator get juneRefresher => MessageTemplateState.new;
}

/// Used to notify the UI that the message template has changed.
class MessageTemplateState extends JuneState {
  MessageTemplateState();
}

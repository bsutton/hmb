import 'package:june/june.dart';

import '../entity/sms_template.dart';
import 'dao.dart';

class DaoSmsTemplate extends Dao<SmsTemplate> {
  @override
  SmsTemplate fromMap(Map<String, dynamic> map) => SmsTemplate.fromMap(map);

  @override
  String get tableName => 'sms_template';

  Future<List<SmsTemplate>> getByFilter(String? filter) async {
    final db = getDb();

    if (filter == null || filter.isEmpty) {
      return getAll(orderByClause: 'modifiedDate desc');
    }

    final data = await db.rawQuery('''
      SELECT * FROM sms_template 
      WHERE title LIKE ? 
      ORDER BY modifiedDate DESC
    ''', ['%$filter%']);

    return toList(data);
  }

  @override
  JuneStateCreator get juneRefresher => SmsTemplateState.new;
}

/// Used to notify the UI that the SMS template has changed.
class SmsTemplateState extends JuneState {
  SmsTemplateState();
}

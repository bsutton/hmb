import 'package:hmb/entity/message_template.dart';
import 'package:test/test.dart';

void main() {
  test('normalizes escaped newline characters from storage', () {
    final template = MessageTemplate.fromMap({
      'id': 1,
      'title': 'Reminder',
      'message': r'Hello\nthere',
      'message_type': MessageType.sms.name,
      'owner': MessageTemplateOwner.user.index,
      'enabled': 1,
      'ordinal': 1,
      'createdDate': DateTime(2026).toIso8601String(),
      'modifiedDate': DateTime(2026).toIso8601String(),
    });

    expect(template.message, 'Hello\nthere');
    expect(template.toMap()['message'], 'Hello\nthere');
  });
}

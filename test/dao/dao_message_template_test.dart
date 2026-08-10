import 'package:hmb/dao/dao_message_template.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('system SMS titles have their matching message bodies', () async {
    final dao = DaoMessageTemplate();
    final appointment = (await dao.getByFilter('Appointment Reminder')).single;
    final completion = (await dao.getByFilter(
      'Job Completion Confirmation',
    )).single;

    expect(appointment.message, contains('Friendly reminder for your job'));
    expect(appointment.message, isNot(contains('feedback')));
    expect(
      completion.message,
      contains('Your job {{job.summary}} is complete'),
    );
    expect(completion.message, isNot(contains('estimate')));
  });
}

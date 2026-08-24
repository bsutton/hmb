import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';
import 'invoice/utility.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test('getByJob returns the most recent time entry first', () async {
    final job = await createJob(
      DateTime(2026, 8, 25),
      BillingType.timeAndMaterial,
      hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
    );
    final task = await createTask(job, 'Ordered entries');
    final older = TimeEntry.forInsert(
      taskId: task.id,
      startTime: DateTime(2026, 8, 25, 8),
      endTime: DateTime(2026, 8, 25, 9),
    );
    final newer = TimeEntry.forInsert(
      taskId: task.id,
      startTime: DateTime(2026, 8, 25, 10),
      endTime: DateTime(2026, 8, 25, 11),
    );
    await DaoTimeEntry().insert(older);
    await DaoTimeEntry().insert(newer);

    final entries = await DaoTimeEntry().getByJob(job.id);

    expect(entries.map((entry) => entry.id), [newer.id, older.id]);
  });
}

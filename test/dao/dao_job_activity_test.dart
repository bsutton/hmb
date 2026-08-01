import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';
import 'invoice/utility.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('gets future job activities for reminder resync', () async {
    final now = DateTime.now();
    final job = await createJob(
      now,
      BillingType.timeAndMaterial,
      hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
    );
    final past = JobActivity.forInsert(
      jobId: job.id,
      start: now.subtract(const Duration(hours: 2)),
      end: now.subtract(const Duration(hours: 1)),
    );
    final future = JobActivity.forInsert(
      jobId: job.id,
      start: now.add(const Duration(hours: 2)),
      end: now.add(const Duration(hours: 3)),
    );
    await DaoJobActivity().insert(past);
    await DaoJobActivity().insert(future);

    final activities = await DaoJobActivity().getStartingAfter(now);

    expect(activities.map((activity) => activity.start), [future.start]);
  });
}

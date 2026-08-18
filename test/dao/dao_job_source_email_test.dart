import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test('finds an imported Gmail message for the connected account', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Imported email job',
    );
    await DaoJobSourceEmail().insert(
      JobSourceEmail.forInsert(
        jobId: job.id,
        accountEmail: 'owner@example.com',
        messageId: 'gmail-message-1',
        threadId: 'gmail-thread-1',
        senderEmail: 'customer@example.com',
        subject: 'Leaking tap',
        receivedAt: DateTime.utc(2026, 8, 14),
      ),
    );

    final found = await DaoJobSourceEmail().getByMessage(
      accountEmail: 'owner@example.com',
      messageId: 'gmail-message-1',
    );
    final otherAccount = await DaoJobSourceEmail().getByMessage(
      accountEmail: 'other@example.com',
      messageId: 'gmail-message-1',
    );

    expect(found?.jobId, job.id);
    expect(found?.subject, 'Leaking tap');
    expect(otherAccount, isNull);
  });

  test(
    'deleting a job allows its Gmail message to be imported again',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Imported email job',
      );
      await DaoJobSourceEmail().insert(
        JobSourceEmail.forInsert(
          jobId: job.id,
          accountEmail: 'owner@example.com',
          messageId: 'gmail-message-1',
          threadId: 'gmail-thread-1',
          senderEmail: 'customer@example.com',
          subject: 'Leaking tap',
          receivedAt: DateTime.utc(2026, 8, 14),
        ),
      );

      await DaoJob().delete(job.id);

      expect(
        await DaoJobSourceEmail().getByMessage(
          accountEmail: 'owner@example.com',
          messageId: 'gmail-message-1',
        ),
        isNull,
      );
    },
  );

  test('removes an orphaned Gmail import left by an older version', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Imported email job',
    );
    await DaoJobSourceEmail().insert(
      JobSourceEmail.forInsert(
        jobId: job.id,
        accountEmail: 'owner@example.com',
        messageId: 'gmail-message-1',
        threadId: 'gmail-thread-1',
        senderEmail: 'customer@example.com',
        subject: 'Leaking tap',
        receivedAt: DateTime.utc(2026, 8, 14),
      ),
    );
    await DaoJob().db.delete('job', where: 'id = ?', whereArgs: [job.id]);

    expect(
      await DaoJobSourceEmail().getByMessage(
        accountEmail: 'owner@example.com',
        messageId: 'gmail-message-1',
      ),
      isNull,
    );

    final replacement = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Replacement imported email job',
    );
    await DaoJobSourceEmail().insert(
      JobSourceEmail.forInsert(
        jobId: replacement.id,
        accountEmail: 'owner@example.com',
        messageId: 'gmail-message-1',
        threadId: 'gmail-thread-1',
        senderEmail: 'customer@example.com',
        subject: 'Leaking tap',
        receivedAt: DateTime.utc(2026, 8, 14),
      ),
    );
  });
}

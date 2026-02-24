import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('inserts and fetches attachments by job', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Attachment test job',
    );

    final attachment = JobAttachment.forInsert(
      jobId: job.id,
      filePath: '/tmp/test-attachment.pdf',
      displayName: 'test-attachment.pdf',
    );
    await DaoJobAttachment().insert(attachment);

    final attachments = await DaoJobAttachment().getByJob(job.id);
    expect(attachments, hasLength(1));
    expect(attachments.first.displayName, 'test-attachment.pdf');
    expect(attachments.first.filePath, '/tmp/test-attachment.pdf');
  });

  test('getByJob excludes attachments from other jobs', () async {
    final jobA = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Attachment test job A',
    );
    final jobB = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Attachment test job B',
    );

    await DaoJobAttachment().insert(
      JobAttachment.forInsert(
        jobId: jobA.id,
        filePath: '/tmp/a.pdf',
        displayName: 'a.pdf',
      ),
    );
    await DaoJobAttachment().insert(
      JobAttachment.forInsert(
        jobId: jobB.id,
        filePath: '/tmp/b.pdf',
        displayName: 'b.pdf',
      ),
    );

    final attachmentsA = await DaoJobAttachment().getByJob(jobA.id);
    expect(attachmentsA, hasLength(1));
    expect(attachmentsA.first.displayName, 'a.pdf');
  });
}

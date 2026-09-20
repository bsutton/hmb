@Tags(['flutter'])
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/job/full_page_list_job_card.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await setupTestDb();
  });
  tearDown(tearDownTestDb);

  for (final status in [
    JobStatus.prospecting,
    JobStatus.quoting,
    JobStatus.awaitingApproval,
  ]) {
    testWidgets('viewing a $status job preserves quote approval status', (
      tester,
    ) async {
      late Job job;
      await tester.runAsync(() async {
        job = (await createJobWithCustomer(
          billingType: BillingType.fixedPrice,
          hourlyRate: MoneyEx.zero,
        ))..status = status;
        await DaoJob().update(job);
      });
      await tester.pumpWidget(MaterialApp(home: FullPageListJobCard(job)));
      for (var attempt = 0; attempt < 30; attempt++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.runAsync(() async {
        final viewed = (await DaoJob().getById(job.id))!;
        expect(viewed.status, status);
        expect(viewed.lastActive, isTrue);
        final quote = Quote.forInsert(
          jobId: job.id,
          summary: 'Quote after viewing job',
          description: '',
          totalAmount: MoneyEx.dollars(100),
        );
        await DaoQuote().insert(quote);
        await DaoQuote().markQuoteSent(quote.id);
        expect(
          (await DaoJob().getById(job.id))!.status,
          JobStatus.awaitingApproval,
        );
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
    });
  }
}

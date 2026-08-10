@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/job/estimator/edit_job_estimate_screen.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:toastification/toastification.dart';

import '../../../../database/management/db_utility_test_helper.dart';
import '../../../ui_test_helpers.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await setupTestDb();
  });

  tearDown(tearDownTestDb);

  testWidgets('raising a quote requires every estimate to be complete', (
    tester,
  ) async {
    late Job job;
    await tester.runAsync(() async {
      job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: MoneyEx.zero,
        summary: 'Incomplete estimate',
      );
      await DaoTask().insert(
        Task.forInsert(
          jobId: job.id,
          name: 'Still estimating',
          description: '',
          status: TaskStatus.awaitingApproval,
        ),
      );
    });

    await tester.pumpWidget(
      ToastificationWrapper(
        child: MaterialApp(home: JobEstimateBuilderScreen(job: job)),
      ),
    );
    await _pumpUntilFound(tester, find.text('Raise Quote'));

    expect(find.text('Estimate Complete: No'), findsOneWidget);
    await tester.tap(find.text('Raise Quote'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.textContaining(
        'Mark every task estimate as complete',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.text('Tasks for Quote'), findsNothing);
    toastification.dismissAll();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  fail('Timed out waiting for $finder');
}

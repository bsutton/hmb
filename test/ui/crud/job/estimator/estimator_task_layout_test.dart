@Tags(['flutter'])
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/job/estimator/edit_job_estimate_screen.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';

import '../../../../database/management/db_utility_test_helper.dart';
import '../../../ui_test_helpers.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await setupTestDb();
  });

  tearDown(tearDownTestDb);

  testWidgets('task titles wrap above the actions on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const taskName =
        'Repair the damaged plaster and repaint the entire hallway';
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
          name: taskName,
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
    expect(tester.widget<Text>(find.text(taskName)).maxLines, isNull);
    expect(
      tester.getRect(find.byTooltip('Edit Task')).top,
      greaterThanOrEqualTo(tester.getRect(find.text(taskName)).bottom),
    );
    toastification.dismissAll();
    await tester.pumpWidget(const SizedBox.shrink());
    // Drain the diagnostic timers retained by asynchronous helpers.
    await tester.pump(const Duration(seconds: 10));
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

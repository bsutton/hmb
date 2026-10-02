@Tags(['flutter'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/job/list_job_screen.dart';
import 'package:hmb/ui/widgets/hmb_button.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('job deletion identifies the customer and job', (tester) async {
    late Job job;
    late Customer customer;
    await tester.runAsync(() async {
      job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Repair verandah',
      );
      customer = (await DaoCustomer().getByJob(job.id))!;
    });

    final harness = await _pumpDeleteHarness(tester, job);
    final firstDialog = harness.navigation.nextDialog;
    await tester.tap(find.text('Start deletion'));
    await runAsyncAndPump(tester, () => firstDialog);
    await _pumpUntilFound(tester, find.text('Delete Job'));

    expect(find.text('Delete Job'), findsOneWidget);
    expect(
      find.text('Delete "Repair verandah" for "${customer.name}"?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(HMBCancelButton, 'Cancel'));
    await tester.pump();
    expect(await tester.runAsync(harness.result), isFalse);
  });

  testWidgets('job deletion requires confirmation for logged time', (
    tester,
  ) async {
    late Job job;
    await tester.runAsync(() async {
      job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
      );
      final taskId = await DaoTask().insert(
        Task.forInsert(
          jobId: job.id,
          name: 'Repair',
          description: '',
          status: TaskStatus.inProgress,
        ),
      );
      await DaoTimeEntry().insert(
        TimeEntry.forInsert(
          taskId: taskId,
          startTime: DateTime(2026, 8, 10, 9),
          endTime: DateTime(2026, 8, 10, 10, 30),
        ),
      );
    });

    final harness = await _pumpDeleteHarness(tester, job);
    final firstDialog = harness.navigation.nextDialog;
    await tester.tap(find.text('Start deletion'));
    await runAsyncAndPump(tester, () => firstDialog);
    await _pumpUntilFound(tester, find.text('Delete Job'));
    final loggedTimeDialog = harness.navigation.nextDialog;
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await runAsyncAndPump(tester, () => loggedTimeDialog);
    await _pumpUntilFound(tester, find.text('Delete Logged Time?'));

    expect(find.text('Delete Logged Time?'), findsOneWidget);
    expect(
      find.textContaining('1h 30m logged across 1 time entry'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(HMBCancelButton, 'Cancel'));
    await tester.pump();
    expect(await tester.runAsync(harness.result), isFalse);
  });

  testWidgets('invoiced jobs cannot enter the deletion flow', (tester) async {
    late Job job;
    await tester.runAsync(() async {
      job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
      );
      await DaoInvoice().insert(
        Invoice.forInsert(
          jobId: job.id,
          dueDate: LocalDate.today(),
          totalAmount: MoneyEx.zero,
          billingContactId: job.billingContactId,
        ),
      );
    });

    final harness = await _pumpDeleteHarness(tester, job);
    await tester.tap(find.text('Start deletion'));
    expect(await tester.runAsync(harness.result), isFalse);
    await tester.pump();

    expect(find.text('Delete Job'), findsNothing);
    expect(await tester.runAsync(() => DaoJob().getById(job.id)), isNotNull);
    toastification.dismissAll();
    await tester.pump(const Duration(seconds: 1));
  });
}

Future<
  ({Future<bool> Function() result, _DeletionNavigationObserver navigation})
>
_pumpDeleteHarness(WidgetTester tester, Job job) async {
  Future<bool>? result;
  final navigation = _DeletionNavigationObserver();
  await tester.pumpWidget(
    ToastificationWrapper(
      child: MaterialApp(
        navigatorObservers: [navigation],
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => result = confirmJobDelete(job, context),
              child: const Text('Start deletion'),
            ),
          ),
        ),
      ),
    ),
  );
  return (result: () => result!, navigation: navigation);
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  fail('Expected UI did not appear: $finder');
}

class _DeletionNavigationObserver extends NavigatorObserver {
  var _nextDialog = Completer<void>();

  Future<void> get nextDialog => _nextDialog.future;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PopupRoute) {
      _nextDialog.complete();
      _nextDialog = Completer<void>();
    }
  }
}

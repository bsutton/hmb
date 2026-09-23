@Tags(['flutter'])
library;

import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/base_full_screen/list_entity_screen.dart';
import 'package:hmb/ui/crud/base_nested/list_nested_screen.dart';
import 'package:hmb/ui/crud/task/list_task_card.dart';
import 'package:hmb/ui/crud/task/list_task_screen.dart';
import 'package:hmb/ui/widgets/hmb_start_time_entry.dart';
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

  testWidgets('successful timer start refreshes order and scrolls to top', (
    tester,
  ) async {
    late Job job;
    await tester.runAsync(() async {
      job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        status: JobStatus.inProgress,
      );
      for (var index = 0; index < 20; index++) {
        await DaoTask().insert(
          Task.forInsert(
            jobId: job.id,
            name: 'Task $index',
            description: '',
            status: TaskStatus.approved,
          ),
        );
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskListScreen(parent: Parent(job), extended: true),
        ),
      ),
    );
    final entityFinder = find.byType(EntityListScreen<Task>);
    await _until(
      tester,
      () =>
          entityFinder.evaluate().isNotEmpty &&
          tester
                  .state<EntityListScreenState<Task>>(entityFinder)
                  .entityList
                  .length ==
              20,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump(const Duration(seconds: 1));
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    expect(controller.offset, greaterThan(0));
    final offset = controller.offset;
    final state = tester.state<EntityListScreenState<Task>>(entityFinder);
    var refreshed = false;
    unawaited(state.refresh().then((_) => refreshed = true));
    await _until(tester, () => refreshed);
    expect(controller.offset, offset);

    final cardFinder = find.byType(ListTaskCard).last;
    final card = tester.widget<ListTaskCard>(cardFinder);
    final updated = card.task.copyWith(status: TaskStatus.inProgress);
    await tester.runAsync(() => DaoTask().update(updated));
    // Exercise the notification emitted after StartWork has committed.
    tester
        .widget<HMBStartTimeEntry>(
          find.descendant(
            of: cardFinder,
            matching: find.byType(HMBStartTimeEntry),
          ),
        )
        .onStart(job, updated);
    await _until(
      tester,
      () => controller.offset == 0 && state.entityList.first.id == updated.id,
    );
    expect(state.entityList.first.status, TaskStatus.inProgress);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(seconds: 1));
  });
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump();
    if (ready()) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
  }
  fail('Task list did not finish updating.');
}

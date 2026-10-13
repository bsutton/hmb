@Tags(['flutter'])
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/dialog/stop_timer_dialog.dart';
import 'package:hmb/ui/widgets/hmb_date_time_picker.dart';
import 'package:hmb/ui/widgets/hmb_start_time_entry.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:june/june.dart';
import 'package:material_ui/material_ui.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await setupTestDb();
  });
  tearDown(() async {
    June.getState<ActiveTimeEntryState>(
      ActiveTimeEntryState.new,
    ).setActiveTimeEntry(null, null, doRefresh: false);
    await tearDownTestDb();
  });

  for (final stopOnly in [false, true]) {
    testWidgets('cancel preserves and stop saves timer (stopOnly=$stopOnly)', (
      tester,
    ) async {
      late Task task;
      late TimeEntry entry;
      final start = DateTime.now().subtract(const Duration(minutes: 30));
      final stop = DateTime(
        start.year,
        start.month,
        start.day,
        start.hour,
        start.minute + 15,
      );
      await tester.runAsync(() async {
        final job = await createJobWithCustomer(
          billingType: BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.zero,
          status: JobStatus.inProgress,
        );
        task = Task.forInsert(
          jobId: job.id,
          name: 'Timer regression',
          description: '',
          status: TaskStatus.inProgress,
        );
        task.id = await DaoTask().insert(task);
        entry = TimeEntry.forInsert(
          taskId: task.id,
          startTime: start,
          note: 'Saved original',
        );
        entry.id = await DaoTimeEntry().insert(entry);
      });
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HMBStartTimeEntry(
              task: task,
              activeTimeEntry: entry,
              stopOnly: stopOnly,
              loadActiveTimeEntry: () async => entry,
              onStart: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Stop task timer'));
      await pumpUntilFound(tester, find.byType(StopTimerDialog));
      await pumpUntilFound(tester, find.text('Job: Test Job'));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('Cancel')).dx,
        lessThan(tester.getCenter(find.text('Stop timer')).dx),
      );
      await tester.enterText(find.byType(TextFormField), 'Discard this edit');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final unchanged = await runAsyncAndPump(
        tester,
        () => DaoTimeEntry().getById(entry.id),
      );
      expect(unchanged!.endTime, isNull);
      expect(unchanged.note, 'Saved original');
      expect(
        June.getState<ActiveTimeEntryState>(
          ActiveTimeEntryState.new,
        ).activeTimeEntry!.id,
        entry.id,
      );
      expect(find.byTooltip('Stop task timer'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester
            .state<HMBStartTimeEntryState>(find.byType(HMBStartTimeEntry))
            .timeEntry!
            .id,
        entry.id,
      );

      await tester.tap(find.byTooltip('Stop task timer'));
      await pumpUntilFound(tester, find.byType(StopTimerDialog));
      await pumpUntilFound(tester, find.text('Job: Test Job'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Confirmed note');
      tester
          .widget<HMBDateTimeField>(find.byType(HMBDateTimeField))
          .onChanged(stop);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop timer'));
      await pumpUntilCondition(
        tester,
        () =>
            June.getState<ActiveTimeEntryState>(
              ActiveTimeEntryState.new,
            ).activeTimeEntry ==
            null,
        'timer to stop',
      );
      final saved = await runAsyncAndPump(
        tester,
        () => DaoTimeEntry().getById(entry.id),
      );
      expect(saved!.endTime, stop);
      expect(saved.note, 'Confirmed note');
      expect(
        saved.startTime.millisecondsSinceEpoch,
        entry.startTime.millisecondsSinceEpoch,
      );
      expect(saved.taskId, task.id);
      expect(
        tester
            .state<HMBStartTimeEntryState>(find.byType(HMBStartTimeEntry))
            .timeEntry,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}

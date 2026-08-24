import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/widgets/hmb_start_time_entry.dart';
import 'package:june/june.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUp(_clearActiveState);
  tearDown(_clearActiveState);

  test('same-job handoff starts one minute after the confirmed stop', () {
    final times = StopStartTime(
      priorTaskStopTime: DateTime(2026, 8, 25, 9, 15),
      startTime: DateTime(2026, 8, 25, 9),
    );
    final stoppedEntry = _stoppedEntry();

    times.applyStoppedEntry(stoppedEntry, sameJob: true);

    expect(times.startTime, DateTime(2026, 8, 25, 9, 16));
  });

  test('cross-job handoff preserves its rounded-down start time', () {
    final roundedStart = DateTime(2026, 8, 25, 9);
    final times = StopStartTime(
      priorTaskStopTime: DateTime(2026, 8, 25, 9, 15),
      startTime: roundedStart,
    )..applyStoppedEntry(_stoppedEntry(), sameJob: false);

    expect(times.startTime, roundedStart);
  });

  test('future timer start displays zero elapsed time', () {
    final now = DateTime(2026, 8, 25, 9);

    expect(
      runningTimerElapsed(
        startTime: now.add(const Duration(minutes: 10)),
        now: now,
      ),
      Duration.zero,
    );
  });

  testWidgets('task adopts a newly published active entry', (tester) async {
    final task = _createTask();
    await tester.pumpWidget(_buildTimer(task));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Start task timer'), findsOneWidget);

    final entry = TimeEntry.forInsert(
      taskId: task.id,
      startTime: DateTime.now().subtract(const Duration(minutes: 2)),
    );
    June.getState<ActiveTimeEntryState>(
      ActiveTimeEntryState.new,
    ).setActiveTimeEntry(entry, task);
    await tester.pump();

    expect(find.byTooltip('Stop task timer'), findsOneWidget);
    expect(find.text('Tap to start tracking time'), findsNothing);

    await _disposeTimerWidget(tester);
  });

  testWidgets('stop-only control cannot render a start action', (tester) async {
    final task = _createTask();
    final entry = TimeEntry.forInsert(
      taskId: task.id,
      startTime: DateTime.now().subtract(const Duration(minutes: 2)),
    );
    June.getState<ActiveTimeEntryState>(
      ActiveTimeEntryState.new,
    ).setActiveTimeEntry(entry, task, doRefresh: false);

    await tester.pumpWidget(_buildTimer(task, activeEntry: entry));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Stop task timer'), findsOneWidget);
    expect(find.byTooltip('Start task timer'), findsNothing);
    expect(find.text('Tap to start tracking time'), findsNothing);

    await _disposeTimerWidget(tester);
  });
}

Future<void> _disposeTimerWidget(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void _clearActiveState() => June.getState<ActiveTimeEntryState>(
  ActiveTimeEntryState.new,
).setActiveTimeEntry(null, null, doRefresh: false);

TimeEntry _stoppedEntry() => TimeEntry.forInsert(
  taskId: 1,
  startTime: DateTime(2026, 8, 25, 8),
  endTime: DateTime(2026, 8, 25, 9, 15),
);

Task _createTask() => Task.forInsert(
  jobId: 1,
  name: 'Timer task',
  description: 'Timer task description',
  status: TaskStatus.inProgress,
)..id = 1;

Widget _buildTimer(Task task, {TimeEntry? activeEntry}) => MaterialApp(
  home: Scaffold(
    body: HMBStartTimeEntry(
      task: task,
      activeTimeEntry: activeEntry,
      stopOnly: activeEntry != null,
      loadActiveTimeEntry: () async => activeEntry,
      onStart: (_, _) {},
    ),
  ),
);

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/dialog/stop_timer_dialog.dart';
import 'package:hmb/ui/widgets/hmb_date_time_picker.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester, {
    required DateTime start,
    required DateTime stop,
    required void Function(TimeEntry?) onResult,
  }) async {
    final task = Task.forInsert(
      jobId: 1,
      name: 'Timer task',
      description: '',
      status: TaskStatus.inProgress,
    )..id = 1;
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(
                await StopTimerDialog.show(
                  context,
                  task: task,
                  timeEntry: TimeEntry.forInsert(
                    taskId: task.id,
                    startTime: start,
                  ),
                  stopTime: stop,
                ),
              ),
              child: const Text('Open timer'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open timer'));
    await tester.pumpAndSettle();
  }

  testWidgets('future handoff starts do not get an earlier suggested stop', (
    tester,
  ) async {
    final start = DateTime(2026, 9, 23, 10, 31);
    TimeEntry? result;
    await openDialog(
      tester,
      start: start,
      stop: DateTime(2026, 9, 23, 10, 30),
      onResult: (entry) => result = entry,
    );
    expect(find.text('Duration: 0h 0m'), findsOneWidget);
    expect(
      tester
          .widget<HMBDateTimeField>(find.byType(HMBDateTimeField))
          .initialDateTime,
      start,
    );
    await tester.tap(find.text('Stop timer'));
    await tester.pumpAndSettle();
    expect(result!.endTime, start);
    expect(result!.duration, Duration.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('negative minute is displayed honestly and cannot be saved', (
    tester,
  ) async {
    final start = DateTime(2026, 9, 23, 10, 31);
    TimeEntry? result;
    await openDialog(
      tester,
      start: start,
      stop: start.add(const Duration(minutes: 15)),
      onResult: (entry) => result = entry,
    );
    await tester.enterText(find.byType(TextFormField), 'Preserve my note');
    tester
        .widget<HMBDateTimeField>(find.byType(HMBDateTimeField))
        .onChanged(start.subtract(const Duration(minutes: 1)));
    await tester.pumpAndSettle();
    expect(find.text('Duration: -0h 1m'), findsOneWidget);
    expect(find.text('Duration: 0h 59m'), findsNothing);
    expect(
      find.text('Stop time must be at or after the start time.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.ancestor(
              of: find.text('Stop timer'),
              matching: find.byType(ElevatedButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Preserve my note'), findsOneWidget);
    expect(result, isNull);

    tester
        .widget<HMBDateTimeField>(find.byType(HMBDateTimeField))
        .onChanged(start.add(const Duration(minutes: 15)));
    await tester.pumpAndSettle();
    expect(find.text('Duration: 0h 15m'), findsOneWidget);
    await tester.tap(find.text('Stop timer'));
    await tester.pumpAndSettle();
    expect(result!.duration, const Duration(minutes: 15));
    expect(result!.note, 'Preserve my note');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a genuine 59-minute duration is accepted', (tester) async {
    TimeEntry? result;
    await openDialog(
      tester,
      start: DateTime(2026, 9, 23, 9, 31),
      stop: DateTime(2026, 9, 23, 10, 30),
      onResult: (entry) => result = entry,
    );
    expect(find.text('Duration: 0h 59m'), findsOneWidget);
    await tester.tap(find.text('Stop timer'));
    await tester.pumpAndSettle();
    expect(result!.duration, const Duration(minutes: 59));
  });

  testWidgets('minute precision does not suggest a stop before start seconds', (
    tester,
  ) async {
    await openDialog(
      tester,
      start: DateTime(2026, 9, 23, 10, 31, 30),
      stop: DateTime(2026, 9, 23, 10, 30),
      onResult: (_) {},
    );
    expect(
      tester
          .widget<HMBDateTimeField>(find.byType(HMBDateTimeField))
          .initialDateTime,
      DateTime(2026, 9, 23, 10, 32),
    );
    expect(find.text('Duration: 0h 0m 30s'), findsOneWidget);
    tester
        .widget<HMBDateTimeField>(find.byType(HMBDateTimeField))
        .onChanged(DateTime(2026, 9, 23, 10, 31));
    await tester.pumpAndSettle();
    expect(find.text('Duration: -0h 0m 30s'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

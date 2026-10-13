import 'package:flutter/services.dart';
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
    Size size = const Size(800, 900),
    double textScale = 1,
    TimeEntry? entry,
  }) async {
    final task = Task.forInsert(
      jobId: 1,
      name: 'Timer task',
      description: '',
      status: TaskStatus.inProgress,
    )..id = 1;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              autofocus: true,
              onPressed: () async => onResult(
                await StopTimerDialog.show(
                  context,
                  task: task,
                  timeEntry:
                      entry ??
                      TimeEntry.forInsert(taskId: task.id, startTime: start),
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

  for (final width in [320.0, 800.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Cancel precedes Stop at $width px and $scale text', (
        tester,
      ) async {
        final start = DateTime(2026, 9, 23, 9);
        final entry = TimeEntry.forInsert(
          taskId: 1,
          startTime: start,
          note: 'Original note',
        );
        var completed = false;
        TimeEntry? result;
        await openDialog(
          tester,
          start: start,
          stop: start.add(const Duration(minutes: 15)),
          entry: entry,
          size: Size(width, 900),
          textScale: scale,
          onResult: (value) {
            completed = true;
            result = value;
          },
        );
        await tester.enterText(find.byType(TextFormField), 'Unsaved note');
        await tester.ensureVisible(find.text('Cancel'));
        await tester.pumpAndSettle();
        final cancel = tester.getRect(
          find.widgetWithText(OutlinedButton, 'Cancel'),
        );
        final stop = tester.getRect(
          find.widgetWithText(ElevatedButton, 'Stop timer'),
        );
        if ((cancel.top - stop.top).abs() < 1) {
          expect(cancel.right, lessThanOrEqualTo(stop.left));
        } else {
          expect(cancel.bottom, lessThanOrEqualTo(stop.top));
          expect(cancel.left, lessThanOrEqualTo(stop.left));
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(completed, isTrue);
        expect(result, isNull);
        expect(entry.endTime, isNull);
        expect(entry.note, 'Original note');
      });
    }
  }

  testWidgets('Tab visits Cancel before Stop and Enter cancels', (
    tester,
  ) async {
    final start = DateTime(2026, 9, 23, 9);
    var completed = false;
    await openDialog(
      tester,
      start: start,
      stop: start.add(const Duration(minutes: 15)),
      onResult: (entry) {
        completed = true;
        expect(entry, isNull);
      },
    );
    await tester.tap(find.byType(TextFormField));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('Cancel'))).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('Stop timer'))).hasFocus, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(Focus.of(tester.element(find.text('Open timer'))).hasFocus, isTrue);
  });

  testWidgets('Escape cancels without returning a stopped entry', (
    tester,
  ) async {
    var completed = false;
    await openDialog(
      tester,
      start: DateTime(2026, 9, 23, 9),
      stop: DateTime(2026, 9, 23, 10),
      onResult: (entry) {
        completed = true;
        expect(entry, isNull);
      },
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  for (final width in [320.0, 800.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('long duration cancellation at $width px and $scale text', (
        tester,
      ) async {
        final start = DateTime(2026, 9, 23, 9);
        TimeEntry? result;
        await openDialog(
          tester,
          start: start,
          size: Size(width, 900),
          textScale: scale,
          stop: start.add(const Duration(days: 2)),
          onResult: (entry) => result = entry,
        );
        await tester.enterText(find.byType(TextFormField), 'Long task note');
        await tester.ensureVisible(find.text('Stop timer'));
        await tester.tap(find.text('Stop timer'));
        await tester.pumpAndSettle();
        final cancel = tester.getRect(
          find.widgetWithText(OutlinedButton, 'Cancel').last,
        );
        final confirm = tester.getRect(
          find.widgetWithText(ElevatedButton, 'Continue'),
        );
        if ((cancel.top - confirm.top).abs() < 1) {
          expect(cancel.right, lessThanOrEqualTo(confirm.left));
        } else {
          expect(cancel.bottom, lessThanOrEqualTo(confirm.top));
          expect(cancel.left, lessThanOrEqualTo(confirm.left));
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(find.text('Long task note'), findsOneWidget);
        await tester.ensureVisible(find.text('Stop timer'));
        await tester.tap(find.text('Stop timer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(result!.duration, const Duration(days: 2));
        expect(result!.note, 'Long task note');
      });
    }
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

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/blocking_ui.dart';
import 'package:hmb/util/dart/log.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() => Log.configure(Directory.current.path));

  testWidgets('fast failures reach the caller without an overlay error', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    final result = BlockingUI().runAndWait<void>(
      () async => throw StateError('fast failure'),
    );
    await expectLater(result, throwsA(isA<StateError>()));
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('nested failures can be handled by the outer action', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    var caught = false;
    await BlockingUI().runAndWait(() async {
      try {
        await BlockingUI().runAndWait<void>(
          () async => throw Exception('nested failure'),
        );
      } on Exception {
        caught = true;
      }
    });
    await tester.pump(const Duration(milliseconds: 1));
    expect(caught, isTrue);
    expect(tester.takeException(), isNull);
  });

  test(
    'slow action forwards an error without leaking an uncaught future',
    () async {
      var ended = false;
      final action = RunningSlowAction<void>(
        'failing action',
        () async => throw StateError('expected failure'),
        () => ended = true,
      );

      final expectedError = expectLater(
        action.completer.future,
        throwsA(isA<StateError>()),
      );
      action.start();

      await expectedError;
      await Future<void>.delayed(Duration.zero);
      expect(ended, isTrue);
    },
  );

  testWidgets('overlay tolerates an action ending between ticker frames', (
    tester,
  ) async {
    final slowAction = Completer<void>();
    await tester.pumpWidget(
      const MaterialApp(home: Stack(children: [BlockingOverlay()])),
    );

    final result = BlockingUI().runAndWait(() => slowAction.future);
    await tester.pump();

    slowAction.complete();
    await result;
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });

  testWidgets('slow action watchdog can report more than once', (tester) async {
    final slowAction = Completer<void>();
    final action = RunningSlowAction<void>(
      'very slow action',
      () => slowAction.future,
      () {},
    )..start();
    await tester.pump(const Duration(seconds: 11));

    expect(tester.takeException(), isNull);

    slowAction.complete();
    await action.completer.future;
  });
}

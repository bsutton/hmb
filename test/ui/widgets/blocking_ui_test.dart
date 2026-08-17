import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/blocking_ui.dart';
import 'package:material_ui/material_ui.dart';

void main() {
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
}

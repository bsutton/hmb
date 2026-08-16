import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/blocking_ui.dart';

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
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/util/flutter/startup_diagnostics.dart';

void main() {
  testWidgets('stalled work reports once and can still finish', (tester) async {
    final outcomes = <String>[];
    final diagnostics = StartupDiagnostics(
      stallThreshold: const Duration(seconds: 2),
      report: (phase, outcome, elapsed, stack, errorType) async {
        outcomes.add('$phase:$outcome');
      },
    );
    final work = Completer<int>();
    final result = diagnostics.run('database', () => work.future);
    await tester.pump(const Duration(seconds: 2));
    expect(outcomes, ['database:stalled']);
    await tester.pump(const Duration(seconds: 10));
    expect(outcomes, hasLength(1));
    work.complete(42);
    expect(await result, 42);
  });

  testWidgets('completed startup cancels stall reporting', (tester) async {
    final outcomes = <String>[];
    final diagnostics = StartupDiagnostics(
      stallThreshold: const Duration(seconds: 2),
      report: (phase, outcome, elapsed, stack, errorType) async {
        outcomes.add(outcome);
      },
    );
    expect(await diagnostics.run('database', () => 42), 42);
    await tester.pump(const Duration(seconds: 3));
    expect(outcomes, isEmpty);
  });

  testWidgets('failure is preserved and reporter errors cannot block startup', (
    tester,
  ) async {
    final error = StateError('private customer data');
    final outcomes = <String>[];
    final diagnostics = StartupDiagnostics(
      stallThreshold: const Duration(seconds: 2),
      report: (phase, outcome, elapsed, stack, errorType) async {
        outcomes.add('$outcome:$errorType');
        await Future<void>.error(StateError('offline'));
      },
    );
    await expectLater(
      diagnostics.run<void>('database', () => throw error),
      throwsA(same(error)),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(outcomes, ['failed:StateError']);
  });
}

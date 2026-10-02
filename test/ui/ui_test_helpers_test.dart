import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'ui_test_helpers.dart';

void main() {
  testWidgets('database verification permits pending widget work to finish', (
    tester,
  ) async {
    final widgetQuery = Completer<void>();
    // Model a widget-owned query holding the connection until its fake-clock
    // continuation runs. A plain awaited runAsync would never advance it.
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 20),
        widgetQuery.complete,
      ),
    );
    final result = await runAsyncAndPump(tester, () async {
      await widgetQuery.future;
      return 42;
    });
    expect(result, 42);
  });
}

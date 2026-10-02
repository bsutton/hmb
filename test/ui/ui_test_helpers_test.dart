import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_helpers.dart';

void main() {
  testWidgets('deferred waits follow newly mounted nested initializers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: _DelayedWidget(child: _DelayedWidget(child: Text('Ready'))),
      ),
    );
    expect(find.text('Ready'), findsNothing);
    await pumpDeferredStates(tester);
    expect(find.text('Ready'), findsOneWidget);
  });

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
  testWidgets('read-only waits follow newly revealed nested query builders', (
    tester,
  ) async {
    final outer = Future<int>.delayed(
      const Duration(milliseconds: 20),
      () => 1,
    );
    final inner = Future<int>.delayed(
      const Duration(milliseconds: 60),
      () => 2,
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          key: const ValueKey('queries'),
          child: FutureBuilder<int>(
            future: outer,
            builder: (_, first) => first.hasData
                ? FutureBuilder<int>(
                    future: inner,
                    builder: (_, second) => Text(
                      second.hasData ? 'Loaded ${second.data}' : 'Waiting',
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await pumpReadOnlyFutureBuilders(
      tester,
      find.byKey(const ValueKey('queries')),
    );
    expect(find.text('Loaded 2'), findsOneWidget);
  });
}

class _DelayedWidget extends StatefulWidget {
  final Widget child;

  const _DelayedWidget({required this.child});

  @override
  State<_DelayedWidget> createState() => _DelayedWidgetState();
}

class _DelayedWidgetState extends DeferredState<_DelayedWidget> {
  @override
  Future<void> asyncInitState() =>
      Future<void>.delayed(const Duration(milliseconds: 40));

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    waitingBuilder: (_) => const SizedBox.shrink(),
    errorBuilder: (_, error) => Text('$error'),
    builder: (_) => widget.child,
  );
}

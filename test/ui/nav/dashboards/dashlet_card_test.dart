@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/nav/dashboards/dashlet_card.dart';

void main() {
  testWidgets('runs before-open callback before dashlet tap action', (
    tester,
  ) async {
    final events = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashletCard<int>.onTap(
            label: 'Tasks',
            hint: 'Open tasks',
            icon: Icons.task,
            value: () async => const DashletValue(1),
            onBeforeOpen: (_) async {
              events.add('before');
              await Future<void>.delayed(Duration.zero);
              events.add('before done');
            },
            onTap: (_) {
              events.add('tap');
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    expect(events, ['before', 'before done', 'tap']);
  });
}

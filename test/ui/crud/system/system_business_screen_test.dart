@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/crud/system/system_business_screen.dart';

import '../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('business details form has screen edge padding', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SystemBusinessScreen()));
    await tester.pumpAndSettle();

    final listView = tester.widget<ListView>(find.byType(ListView));

    expect(listView.padding, const EdgeInsets.all(16));
  });

  testWidgets('business details fits phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: SystemBusinessScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

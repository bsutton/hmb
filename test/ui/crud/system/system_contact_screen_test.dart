@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/crud/system/system_contact_screen.dart';

import '../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('business contacts form has screen edge padding', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SystemContactInformationScreen()),
    );
    await _pumpContactScreen(tester);

    final listView = tester.widget<ListView>(find.byType(ListView));

    expect(listView.padding, const EdgeInsets.all(16));
  });

  testWidgets('business contacts country field fits phone width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: SystemContactInformationScreen()),
    );
    await _pumpContactScreen(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpContactScreen(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    final exception = tester.takeException();
    if (exception != null) {
      fail('Business contacts failed to initialise: $exception');
    }
    if (find.text('First Name').evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 1));
      return;
    }
  }
  fail('Business contacts did not render the form.');
}

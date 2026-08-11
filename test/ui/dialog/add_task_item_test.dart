@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/dialog/add_task_item.dart';

import '../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('packing item dialog requires a description', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showAddItemDialog(context, AddType.packing),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Summary'), findsNothing);

    await tester.tap(find.text('Add'));
    await tester.pump();

    expect(find.text('Please enter a Description'), findsOneWidget);
  });

  testWidgets('shopping item cost defaults to zero', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showAddItemDialog(context, AddType.shopping),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final quantity = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Quantity'),
    );
    final cost = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Cost per item'),
    );

    expect(quantity.controller!.text, '1');
    expect(cost.controller!.text, r'$0.00');

    await tester.tap(find.text('Add'));
    await tester.pump();

    expect(find.text('Enter a valid cost'), findsNothing);
  });
}

@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/widgets/select/hmb_select_job.dart';

import '../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('can hide add button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HMBSelectJob(
            selectedJob: SelectedJob(),
            showAdd: false,
            items: (_) async => const <Job>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('can hide add button in selection dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HMBSelectJob(
            selectedJob: SelectedJob(),
            showAdd: false,
            items: (_) async => const <Job>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a Job'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('shows add button by default in selection dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HMBSelectJob(selectedJob: SelectedJob())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a Job'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('shows active filter icon by default in selection dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HMBSelectJob(selectedJob: SelectedJob(), showAdd: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a Job'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final filterIcon = tester.widget<Icon>(find.byIcon(Icons.tune));
    expect(filterIcon.color, Colors.blue);
  });
}

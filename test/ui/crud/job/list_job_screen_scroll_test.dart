@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/base_full_screen/list_entity_screen.dart';
import 'package:hmb/ui/crud/job/list_job_screen.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('returning to recent jobs resets the scroll position', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (var index = 0; index < 4; index++) {
        await createJobWithCustomer(
          billingType: BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.zero,
          summary: 'Recent job $index',
        );
      }
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: JobListScreen())),
    );
    await _pumpUntilJobsLoad(tester);

    final listFinder = find.byType(ListView);
    await tester.drag(listFinder, const Offset(0, -600));
    await tester.pump(const Duration(seconds: 1));
    final list = tester.widget<ListView>(listFinder);
    expect(list.controller!.offset, greaterThan(0));

    tester
        .state<EntityListScreenState<Job>>(find.byType(EntityListScreen<Job>))
        .didPopNext();
    await _pumpUntilScrolledToTop(tester, list.controller!);

    expect(list.controller!.offset, 0);
    await _disposeHarness(tester);
  });
}

Future<void> _pumpUntilJobsLoad(WidgetTester tester) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump();
    if (find.text('Recent job 3').evaluate().isNotEmpty) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  fail('Job list did not load.');
}

Future<void> _pumpUntilScrolledToTop(
  WidgetTester tester,
  ScrollController controller,
) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump();
    if (controller.offset == 0) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  fail('Job list did not reset its scroll position.');
}

Future<void> _disposeHarness(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
}

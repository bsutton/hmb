@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_job.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/job/fsm_status_picker.dart';
import 'package:hmb/ui/widgets/hmb_button.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../../database/management/db_utility_test_helper.dart';

void main() {
  testWidgets('shows actions and persists a selected action before callback', (
    tester,
  ) async {
    late Job job;
    JobStatus? savedStatus;
    await tester.runAsync(() async {
      await setupTestDb();
      job = Job.forInsert(
        customerId: 1,
        summary: 'Action picker test',
        description: '',
        siteId: 1,
        contactId: 1,
        status: JobStatus.inProgress,
        hourlyRate: MoneyEx.zero,
        bookingFee: MoneyEx.zero,
        lastActive: true,
        billingContactId: 1,
      );
      job.id = await DaoJob().insert(job);
    });
    addTearDown(tearDownTestDb);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FsmStatusPicker(
            job: job,
            onStatusChanged: () {
              savedStatus = job.status;
            },
          ),
        ),
      ),
    );
    await _pumpUntil(tester, find.text('Pause job - On Hold'));

    final labels = tester
        .widgetList<HMBButtonPrimary>(find.byType(HMBButtonPrimary))
        .map((button) => button.label);
    expect(
      labels,
      containsAll([
        'Pause job - On Hold',
        'Mark work complete - Completed',
        'Reject job - Rejected',
      ]),
    );
    expect(labels, isNot(contains('In Progress')));
    expect(find.text('Status: Completed'), findsNothing);
    expect(find.text('Move to:'), findsNothing);

    await tester.tap(find.text('Mark work complete - Completed'));
    await _pumpUntil(tester, find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await _pumpUntil(tester, find.text('Reopen job - In Progress'));
    await tester.runAsync(() async {
      expect((await DaoJob().getById(job.id))!.status, JobStatus.completed);
    });
    await tester.pumpAndSettle();
    expect(savedStatus, JobStatus.completed);
    expect(find.text('Reopen job - In Progress'), findsOneWidget);
    expect(find.text('Mark work complete - Completed'), findsNothing);
    // fsm2's CompleterEx leaves a 10-second diagnostic timer after completion.
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });
}

// Advance Flutter's test clock as well as the real database/async work.
Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 300; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
  }
  expect(finder, findsWidgets);
}

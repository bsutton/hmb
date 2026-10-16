@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_job.dart';
import 'package:hmb/dao/dao_job_activity.dart';
import 'package:hmb/entity/job.dart';
import 'package:hmb/entity/job_activity.dart';
import 'package:hmb/entity/job_status.dart';
import 'package:hmb/ui/scheduling/job_activity_dialog.dart';
import 'package:hmb/ui/scheduling/job_activity_ex.dart';
import 'package:hmb/ui/widgets/hmb_button.dart';
import 'package:material_ui/material_ui.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  testWidgets('adding without a job validates instead of crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobActivityDialog.add(when: DateTime(2099, 1, 1, 9)),
        ),
      ),
    );
    await pumpDeferredStates(tester);
    await pumpReadOnlyFutureBuilders(tester, find.byType(JobActivityDialog));
    await tester.ensureVisible(find.text('Add Event'));
    await tester.tap(find.text('Add Event'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(JobActivityDialog), findsOneWidget);
    expect(find.text('Please select a job before saving.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('adds once with no optional customer, contact or site', (
    tester,
  ) async {
    final job = await runAsyncAndPump(tester, _insertJob);
    final results = <Object?>[];
    await _open(
      tester,
      JobActivityDialog.add(
        when: DateTime(2099, 1, 1, 9),
        preSelectedJobId: job.id,
      ),
      results.add,
    );
    await tester.enterText(find.byType(TextFormField).last, 'Keep these notes');
    await _saveTwice(tester, 'Add Event');
    await pumpUntilCondition(tester, () => results.isNotEmpty, 'add result');
    expect(results, hasLength(1));
    final result = results.single! as JobActivityAddAction;
    expect(result.action, AddAction.add);
    expect(result.jobActivity!.jobActivity.jobId, job.id);
    expect(result.jobActivity!.jobActivity.notes, 'Keep these notes');
    expect(result.jobActivity!.jobActivity.start, DateTime(2099, 1, 1, 9));
    expect(result.jobActivity!.jobActivity.end, DateTime(2099, 1, 1, 13));
    // The dialog only returns a proposal; the caller owns persistence.
    expect(
      await runAsyncAndPump(tester, () => DaoJobActivity().getByJob(job.id)),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('updates the same activity without mutating or inserting', (
    tester,
  ) async {
    final job = await runAsyncAndPump(tester, _insertJob);
    final activity = JobActivity.forInsert(
      jobId: job.id,
      start: DateTime(2099, 1, 1, 9),
      end: DateTime(2099, 1, 1, 13),
      notes: 'Original',
      noticeSentDate: DateTime(2098),
    );
    await runAsyncAndPump(tester, () => DaoJobActivity().insert(activity));
    final ex = await runAsyncAndPump(
      tester,
      () => JobActivityEx.fromActivity(activity),
    );
    final results = <Object?>[];
    await _open(
      tester,
      JobActivityDialog.edit(event: ex.eventData),
      results.add,
    );
    await tester.enterText(find.byType(TextFormField).last, 'Updated');
    await _saveTwice(tester, 'Update Event');
    await pumpUntilCondition(tester, () => results.isNotEmpty, 'update result');
    expect(results, hasLength(1));
    final result = results.single! as JobActivityUpdateAction;
    expect(result.action, EditAction.update);
    expect(result.jobActivity!.jobActivity.id, activity.id);
    expect(result.jobActivity!.jobActivity.notes, 'Updated');
    expect(result.jobActivity!.jobActivity.noticeSentDate, DateTime(2098));
    expect(activity.notes, 'Original');
    final stored = await runAsyncAndPump(
      tester,
      () => DaoJobActivity().getByJob(job.id),
    );
    expect(stored, hasLength(1));
    expect(stored.single.notes, 'Original');
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing preselected job cannot produce an activity', (
    tester,
  ) async {
    final results = <Object?>[];
    await _open(
      tester,
      JobActivityDialog.add(
        when: DateTime(2099, 1, 1, 9),
        preSelectedJobId: 999999,
      ),
      results.add,
    );
    await _saveTwice(tester, 'Add Event');
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(find.text('Please select an item'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('job deleted while dialog is open preserves the draft', (
    tester,
  ) async {
    final job = await runAsyncAndPump(tester, _insertJob);
    final results = <Object?>[];
    await _open(
      tester,
      JobActivityDialog.add(
        when: DateTime(2099, 1, 1, 9),
        preSelectedJobId: job.id,
      ),
      results.add,
    );
    await tester.enterText(find.byType(TextFormField).last, 'Keep me');
    await runAsyncAndPump(
      tester,
      () => testDb!.delete('job', where: 'id = ?', whereArgs: [job.id]),
    );
    await _saveTwice(tester, 'Add Event');
    await pumpUntilFound(tester, find.textContaining('no longer available'));
    expect(results, isEmpty);
    expect(find.text('Keep me'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('lookup failure keeps notes and permits one successful retry', (
    tester,
  ) async {
    final job = await runAsyncAndPump(tester, _insertJob);
    final results = <Object?>[];
    await _open(
      tester,
      JobActivityDialog.add(
        when: DateTime(2099, 1, 1, 9),
        preSelectedJobId: job.id,
      ),
      results.add,
    );
    await tester.enterText(find.byType(TextFormField).last, 'Retry draft');
    await runAsyncAndPump(
      tester,
      () => testDb!.execute(
        'ALTER TABLE job_activity RENAME TO held_job_activity',
      ),
    );
    await _saveTwice(tester, 'Add Event');
    await pumpUntilFound(tester, find.textContaining('Unable to check'));
    expect(results, isEmpty);
    expect(find.text('Retry draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await runAsyncAndPump(
      tester,
      () => testDb!.execute(
        'ALTER TABLE held_job_activity RENAME TO job_activity',
      ),
    );
    await _saveTwice(tester, 'Add Event');
    await pumpUntilCondition(tester, () => results.isNotEmpty, 'retry result');
    expect(results, hasLength(1));
    expect(
      (results.single! as JobActivityAddAction).jobActivity!.jobActivity.notes,
      'Retry draft',
    );
    expect(
      await runAsyncAndPump(tester, () => DaoJobActivity().getByJob(job.id)),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing during overlap confirmation returns no save', (
    tester,
  ) async {
    final job = await runAsyncAndPump(tester, _insertJob);
    await runAsyncAndPump(
      tester,
      () => DaoJobActivity().insert(
        JobActivity.forInsert(
          jobId: job.id,
          start: DateTime(2099, 1, 1, 10),
          end: DateTime(2099, 1, 1, 12),
        ),
      ),
    );
    final results = <Object?>[];
    await _open(
      tester,
      JobActivityDialog.add(
        when: DateTime(2099, 1, 1, 9),
        preSelectedJobId: job.id,
      ),
      results.add,
    );
    final element = tester.element(find.byType(JobActivityDialog));
    final route = ModalRoute.of(element)!;
    final navigator = Navigator.of(element);
    await _saveTwice(tester, 'Add Event');
    await pumpUntilFound(tester, find.text('Event Overlap'));
    navigator.removeRoute(route);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(results, [null]);
    expect(
      await runAsyncAndPump(tester, () => DaoJobActivity().getByJob(job.id)),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<Job> _insertJob() async {
  final job = Job.forInsert(
    customerId: null,
    summary: 'Synthetic schedule job',
    description: '',
    siteId: null,
    contactId: null,
    status: JobStatus.toBeScheduled,
    hourlyRate: null,
    bookingFee: null,
    billingContactId: null,
  );
  await DaoJob().insert(job);
  return job;
}

Future<void> _open(
  WidgetTester tester,
  JobActivityDialog dialog,
  void Function(Object?) onResult,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<Object>(
                context: context,
                builder: (_) => Material(child: dialog),
              );
              onResult(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  await pumpDeferredStates(tester);
  await pumpReadOnlyFutureBuilders(tester, find.byType(JobActivityDialog));
  await tester.pumpAndSettle();
}

Future<void> _saveTwice(WidgetTester tester, String label) async {
  final button = tester.widget<HMBButtonPrimary>(
    find.byWidgetPredicate(
      (widget) => widget is HMBButtonPrimary && widget.label == label,
    ),
  );
  // Exercise rapid callbacks before Flutter has rebuilt the disabled button.
  button.onPressed!();
  button.onPressed!();
  await tester.pump();
}

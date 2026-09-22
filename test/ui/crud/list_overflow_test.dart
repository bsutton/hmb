@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/base_nested/list_nested_screen.dart';
import 'package:hmb/ui/crud/todo/list_todo_screen.dart';
import 'package:hmb/ui/crud/work_assignment/list_assignment_screen.dart';
import 'package:hmb/ui/widgets/layout/hmb_full_page_child_screen.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  for (final scale in [1.0, 2.0]) {
    testWidgets('todo list fits narrow screens at text scale $scale', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final job = await createJobWithCustomer(
          billingType: BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.zero,
          summary: 'Repair the weatherboards along the entire rear verandah',
        );
        await DaoToDo().insert(
          ToDo.forInsert(
            title: 'Confirm materials and arrange delivery with the customer',
            parentType: ToDoParentType.job,
            parentId: job.id,
            dueDate: DateTime(2030, 10, 20, 10),
            note:
                'Check the access arrangements and delivery instructions '
                'before confirming the order with the supplier.',
          ),
        );
      });
      await _pumpNarrow(tester, const ToDoListScreen(), scale);
      await _waitFor(tester, find.textContaining('Job: Repair'));
      await _waitFor(tester, find.textContaining('Customer:'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Snooze'),
        150,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Snooze').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('assignment list grows with tasks at text scale $scale', (
      tester,
    ) async {
      late Job job;
      await tester.runAsync(() async {
        job = await createJobWithCustomer(
          billingType: BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.zero,
        );
        final supplier = Supplier.forInsert(
          name: 'Example Specialist Building and Maintenance Services',
          businessNumber: '',
          description: '',
          bsb: '',
          accountNumber: '',
          service: '',
        );
        await DaoSupplier().insert(supplier);
        final contact = Contact.forInsert(
          firstName: 'Alexandra',
          surname: 'Example Contact With A Long Name',
          mobileNumber: '0400000000',
          landLine: '',
          officeNumber: '',
          emailAddress: 'example@example.com',
        );
        await DaoContact().insert(contact);
        final assignment = WorkAssignment.forInsert(
          jobId: job.id,
          supplierId: supplier.id,
          contactId: contact.id,
        );
        await DaoWorkAssignment().insert(assignment);
        for (var i = 0; i < 8; i++) {
          final task = Task.forInsert(
            jobId: job.id,
            name: 'Assigned task $i',
            description: '',
            status: TaskStatus.inProgress,
          );
          await DaoTask().insert(task);
          await DaoWorkAssignmentTask().insert(
            WorkAssignmentTask.forInsert(
              assignmentId: assignment.id,
              taskId: task.id,
            ),
          );
        }
      });
      await _pumpNarrow(
        tester,
        HMBFullPageChildScreen(
          title: 'Assignments',
          child: AssignmentListScreen(parent: Parent(job)),
        ),
        scale,
      );
      await _waitFor(tester, find.textContaining('Assigned task 7'));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.textContaining('Assigned task 7'),
        200,
      );
      expect(
        find.textContaining('Assigned task 7').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty assignment list wraps at text scale $scale', (
      tester,
    ) async {
      late Job job;
      await tester.runAsync(() async {
        job = await createJobWithCustomer(
          billingType: BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.zero,
        );
      });
      await _pumpNarrow(
        tester,
        HMBFullPageChildScreen(
          title: 'Assignments',
          child: AssignmentListScreen(parent: Parent(job)),
        ),
        scale,
      );
      await _waitFor(tester, find.text('to add a Supplier Assignment.'));
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpNarrow(
  WidgetTester tester,
  Widget child,
  double scale,
) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: HMBTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    ),
  );
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      await tester.pump();
      return;
    }
  }
  throw TestFailure('Timed out waiting for $finder');
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_customer.dart';
import 'package:hmb/dao/dao_todo.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/todo/list_todo_card.dart';
import 'package:money2/money2.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitForText(
    WidgetTester tester,
    String text, {
    int attempts = 30,
  }) async {
    for (var i = 0; i < attempts; i++) {
      if (find.text(text).evaluate().isNotEmpty) {
        return;
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
    throw TestFailure('Timed out waiting for text: $text');
  }

  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('shows customer name for job-linked todo', (tester) async {
    late ToDo todo;
    late String customerName;
    await tester.runAsync(() async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(10000, isoCode: 'AUD'),
      );
      customerName = (await DaoCustomer().getByJob(job.id))!.name;

      final todoId = await DaoToDo().insert(
        ToDo.forInsert(
          title: 'Follow up on schedule',
          parentType: ToDoParentType.job,
          parentId: job.id,
        ),
      );

      todo = (await DaoToDo().getById(todoId))!;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ListTodoCard(todo: todo)),
      ),
    );

    await tester.pumpAndSettle();
    await waitForText(tester, 'Customer: $customerName');

    expect(find.text('Customer: $customerName'), findsOneWidget);
  });
}

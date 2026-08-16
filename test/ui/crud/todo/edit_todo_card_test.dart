@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/todo.dart';
import 'package:hmb/ui/crud/todo/edit_todo_card.dart';
import 'package:hmb/ui/crud/todo/edit_todo_screen.dart';

void main() {
  test('new To-Dos enable a future reminder by default', () {
    final todo = createNewToDoDraft(now: DateTime(2026, 8, 14, 22));

    expect(todo.remindAt, DateTime(2026, 8, 15, 9));
    expect(todo.status, ToDoStatus.open);
  });

  testWidgets('reminder switch stores and clears the displayed reminder', (
    tester,
  ) async {
    var todo = ToDo.forInsert(title: 'Call customer');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => ToDoEditorCard(
                todo: todo,
                onChanged: (updated) => setState(() => todo = updated),
              ),
            ),
          ),
        ),
      ),
    );

    expect(todo.remindAt, isNull);
    expect(find.text('Reminder'), findsNothing);

    final reminderSwitch = find.descendant(
      of: find.byKey(const ValueKey('todo_reminder_enabled')),
      matching: find.byType(Switch),
    );
    await tester.tap(reminderSwitch);
    await tester.pump();

    expect(todo.remindAt, isNotNull);
    expect(todo.remindAt!.isAfter(DateTime.now()), isTrue);
    expect(find.text('Reminder'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('todo_due_date_enabled')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pump();

    expect(todo.dueDate, isNotNull);
    expect(todo.dueDate!.difference(todo.remindAt!), const Duration(days: 1));

    await tester.ensureVisible(reminderSwitch);
    await tester.pumpAndSettle();
    await tester.tap(reminderSwitch);
    await tester.pump();

    expect(todo.remindAt, isNull);
    expect(find.text('Reminder'), findsNothing);
  });
}

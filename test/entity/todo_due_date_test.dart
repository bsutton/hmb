import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/todo.dart';

void main() {
  group('ToDo.withDueDate', () {
    test('preserves reminder lead time when the new due date passes it', () {
      final todo = ToDo.forInsert(
        title: 'Call customer',
        dueDate: DateTime(2026, 7, 10, 12),
        remindAt: DateTime(2026, 7, 9, 8),
      );

      final updated = todo.withDueDate(DateTime(2026, 7, 8, 12));

      expect(updated.dueDate, DateTime(2026, 7, 8, 12));
      expect(updated.remindAt, DateTime(2026, 7, 7, 8));
    });

    test('moves reminder with a later due date', () {
      final reminder = DateTime(2026, 7, 9, 8);
      final todo = ToDo.forInsert(
        title: 'Call customer',
        dueDate: DateTime(2026, 7, 10, 12),
        remindAt: reminder,
      );

      final updated = todo.withDueDate(DateTime(2026, 7, 12, 12));

      expect(updated.dueDate, DateTime(2026, 7, 12, 12));
      expect(updated.remindAt, DateTime(2026, 7, 11, 8));
    });

    test('does not create a reminder when reminders are disabled', () {
      final todo = ToDo.forInsert(
        title: 'Call customer',
        dueDate: DateTime(2026, 7, 10, 12),
      );

      final updated = todo.withDueDate(DateTime(2026, 7, 12, 12));

      expect(updated.dueDate, DateTime(2026, 7, 12, 12));
      expect(updated.remindAt, isNull);
    });
  });

  test('optional due date and reminder can be explicitly cleared', () {
    final todo = ToDo.forInsert(
      title: 'Test',
      dueDate: DateTime(2026, 8, 20, 9),
      remindAt: DateTime(2026, 8, 19, 9),
    );

    final cleared = todo.copyWith(clearDueDate: true, clearReminder: true);

    expect(cleared.dueDate, isNull);
    expect(cleared.remindAt, isNull);
  });
}

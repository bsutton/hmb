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

    test('leaves a reminder unchanged when it remains before the due date', () {
      final reminder = DateTime(2026, 7, 9, 8);
      final todo = ToDo.forInsert(
        title: 'Call customer',
        dueDate: DateTime(2026, 7, 10, 12),
        remindAt: reminder,
      );

      final updated = todo.withDueDate(DateTime(2026, 7, 12, 12));

      expect(updated.dueDate, DateTime(2026, 7, 12, 12));
      expect(updated.remindAt, reminder);
    });
  });
}

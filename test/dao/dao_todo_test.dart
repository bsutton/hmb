import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_todo.dart';
import 'package:hmb/entity/todo.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('persists closed todo status', () async {
    final id = await DaoToDo().insert(
      ToDo.forInsert(
        title: 'Archive old note',
        status: ToDoStatus.closed,
      ),
    );

    final todo = await DaoToDo().getById(id);
    expect(todo, isNotNull);
    expect(todo!.status, ToDoStatus.closed);
  });
}

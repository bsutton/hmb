import 'package:june/june.dart';

import '../entity/todo.dart';
import 'dao.g.dart';

class DaoToDo extends Dao<ToDo> {
  @override
  ToDo fromMap(Map<String, dynamic> m) => ToDo.fromMap(m);
  @override
  String get tableName => 'to_do';

  Future<List<ToDo>> getFiltered({
    required ToDoStatus status,
    String? filter,
  }) async {
    final db = withoutTransaction();
    final whereClause = StringBuffer('WHERE ');
    final args = <Object?>[];

    if ((filter ?? '').trim().isNotEmpty) {
      whereClause
        ..write('title LIKE ?')
        ..write(" AND '%?%")
        ..write(' AND ');
      args
        ..add(filter)
        ..add(filter);
    }

    final state = status.name;
    args.add(state);
    whereClause.write(' status = ?');

    // Derived ordering: overdue -> today -> upcoming -> none
    final sql =
        '''
      SELECT * FROM to_do
      $whereClause
      ORDER BY
        CASE
          WHEN due_date IS NOT NULL AND datetime(due_date) < datetime('now') THEN 0
          WHEN date(due_date) = date('now') THEN 1
          WHEN due_date IS NOT NULL THEN 2
          ELSE 3
        END,
        due_date ASC NULLS LAST,
        modified_date DESC
    ''';

    final rows = await db.rawQuery(sql, args);
    return rows.map(fromMap).toList();
  }

  Future<void> toggleDone(ToDo t) async {
    final updated = t.status == ToDoStatus.done
        ? ToDo.forUpdate(
            entity: t,
            title: t.title,
            status: ToDoStatus.open,
            priority: t.priority,
            note: t.note,
            dueDate: t.dueDate,
            remindAt: t.remindAt,
            parentType: t.parentType,
            parentId: t.parentId,
          )
        : ToDo.forUpdate(
            entity: t,
            title: t.title,
            status: ToDoStatus.done,
            priority: t.priority,
            note: t.note,
            dueDate: t.dueDate,
            parentType: t.parentType,
            parentId: t.parentId,
            completedDate: DateTime.now(),
          );
    await update(updated);
  }

  Future<void> snooze(ToDo t, Duration by) async {
    final due = (t.dueDate ?? DateTime.now()).add(by);
    final remind = t.remindAt?.add(by);
    final u = ToDo.forUpdate(
      entity: t,
      title: t.title,
      status: t.status,
      priority: t.priority,
      note: t.note,
      dueDate: due,
      remindAt: remind,
      parentType: t.parentType,
      parentId: t.parentId,
      completedDate: t.completedDate,
    );
    await update(u);
  }

  @override
  JuneStateCreator get juneRefresher => ToDoState.new;

  Future<void> convertToTask(ToDo t) async {
    // Implement with your existing Task CRUD; after creation you can mark done
    // or link the new task id back if you want a reference.
  }

  Future<List<ToDo>> getByJob(int id) async {
    final db = withoutTransaction();

    // We assume ToDo has a parentType/parentId system for linking to jobs
    // and that 'job' is the correct enum/db string for a job parent type.
    final parentTypeJob = ToDoParentType.job.name;

    final maps = await db.query(
      tableName,
      where: 'parent_type = ? AND parent_id = ?',
      whereArgs: [parentTypeJob, id],
      orderBy: 'due_date ASC, created_date DESC', // earliest due first
    );

    return maps.map(ToDo.fromMap).toList();
  }

  /// Get a list of open todo's that have reminders set
  Future<List<ToDo>> getOpenWithReminders() async {
    final db = withoutTransaction();

    // Include slightly past reminders so near-now saves aren’t missed.
    final cutoffIso = DateTime.now()
        .toUtc()
        .subtract(const Duration(seconds: 60))
        .toIso8601String();

    final rows = await db.query(
      tableName, // e.g. 'to_do'
      where: 'status = ? AND remind_at IS NOT NULL AND remind_at > ?',
      whereArgs: [ToDoStatus.open.name, cutoffIso],
      orderBy: 'remind_at ASC, created_date ASC',
    );

    return rows.map(ToDo.fromMap).toList();
  }
}

class ToDoState extends JuneState {
  ToDoState();
}

import '../entity/todo.dart';
import '../util/dart/local_date.dart';
import 'dao.g.dart';

class DaoToDo extends Dao<ToDo> {
  static const tableName = 'to_do';
  DaoToDo() : super(tableName);
  @override
  ToDo fromMap(Map<String, dynamic> m) => ToDo.fromMap(m);

  Future<List<ToDo>> getFiltered({
    required ToDoStatus status,
    String? filter,
  }) async {
    final db = withoutTransaction();

    final whereParts = <String>[];
    final args = <Object?>[];

    // Optional case-insensitive text filter (matches title OR note).
    final f = (filter ?? '').trim();
    if (f.isNotEmpty) {
      whereParts.add(
        "(title LIKE '%' || ? || '%' COLLATE NOCASE "
        "OR note LIKE '%' || ? || '%' COLLATE NOCASE)",
      );
      args
        ..add(f)
        ..add(f);
    }

    // Required status filter
    whereParts.add('status = ?');
    args.add(status.name);

    final whereSql = whereParts.isEmpty
        ? ''
        : 'WHERE ${whereParts.join(' AND ')}';

    // Derived ordering: overdue -> today -> upcoming -> none
    final sql =
        '''
    SELECT * FROM to_do
    $whereSql
    ORDER BY
      CASE
        WHEN due_date IS NOT NULL AND datetime(due_date) < datetime('now') THEN 0
        WHEN date(due_date) = date('now') THEN 1
        WHEN due_date IS NOT NULL THEN 2
        ELSE 3
      END,
      (due_date IS NULL),
      due_date ASC,
      modified_date DESC
  ''';

    final rows = await db.rawQuery(sql, args);
    return rows.map(fromMap).toList();
  }

  Future<void> toggleDone(ToDo t) async {
    final updated = t.status == ToDoStatus.done
        ? t.copyWith(
            title: t.title,
            status: ToDoStatus.open,
            priority: t.priority,
            note: t.note,
            dueDate: t.dueDate,
            remindAt: t.remindAt,
            parentType: t.parentType,
            parentId: t.parentId,
          )
        : t.copyWith(
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
    final u = t.copyWith(
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

  /// Get open todos due today or overdue.
  Future<List<ToDo>> getDueByDate(LocalDate dueBy) async {
    final db = withoutTransaction();

    final endOfDate = dueBy.endOfDay();
    final endIso = endOfDate.toUtc().toIso8601String();

    final rows = await db.query(
      tableName,
      where: '''
      status = ?
      AND due_date IS NOT NULL
      AND (
        due_date <= ?              
      )
    ''',
      whereArgs: [
        ToDoStatus.open.name,
        endIso, // today upper bound
      ],
      orderBy: 'due_date ASC, created_date ASC',
    );

    return rows.map(ToDo.fromMap).toList();
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

  /// Get a list of open todo's
  Future<List<ToDo>> getOpenByJob(int jobId) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName, // e.g. 'to_do'
      where: '''
status = ? AND parent_type = '${ToDoParentType.job.name}' and parent_id = ?''',
      whereArgs: [ToDoStatus.open.name, jobId],
      orderBy: 'remind_at ASC, created_date ASC',
    );

    return rows.map(ToDo.fromMap).toList();
  }
}

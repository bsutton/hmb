// lib/src/entity/work_assignment_task.dart

import 'entity.dart';

class WorkAssignmentTask extends Entity<WorkAssignmentTask> {
  WorkAssignmentTask({
    required super.id,
    required this.assignmentId,
    required this.taskId,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  WorkAssignmentTask.forInsert({
    required this.assignmentId,
    required this.taskId,
  }) : super.forInsert();

  WorkAssignmentTask.forUpdate({
    required super.entity,
    required this.assignmentId,
    required this.taskId,
  }) : super.forUpdate();

  factory WorkAssignmentTask.fromMap(Map<String, dynamic> map) =>
      WorkAssignmentTask(
        id: map['id'] as int,
        assignmentId: map['assignment_id'] as int,
        taskId: map['task_id'] as int,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'assignment_id': assignmentId,
    'task_id': taskId,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };

  int assignmentId;
  int taskId;
}

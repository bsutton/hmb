import 'package:money2/money2.dart';

import 'entity.dart';

class Task extends Entity<Task> {
  Task(
      {required super.id,
      required this.jobId,
      required this.name,
      required this.description,
      required this.completed,
      required this.effortInHours,
      required this.estimatedCost,
      required this.taskStatusId,
      required super.createdDate,
      required super.modifiedDate})
      : super();

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        id: map['id'] as int,
        jobId: map['jobId'] as int,
        name: map['name'] as String,
        description: map['description'] as String,
        completed: map['completed'] == 1,
        effortInHours: Fixed.fromInt(map['effort_in_hours'] as int),
        estimatedCost:
            Money.fromInt(map['estimated_cost'] as int, isoCode: 'AUD'),
        taskStatusId: map['task_status_id'] as int,
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
      );

  Task.forInsert(
      {required this.jobId,
      required this.name,
      required this.description,
      required this.completed,
      required this.effortInHours,
      required this.estimatedCost,
      required this.taskStatusId})
      : super.forInsert();

  Task.forUpdate(
      {required super.entity,
      required this.jobId,
      required this.name,
      required this.description,
      required this.completed,
      required this.effortInHours,
      required this.estimatedCost,
      required this.taskStatusId})
      : super.forUpdate();

  int jobId;
  String name;
  String description;
  bool completed;
  Fixed? effortInHours;
  Money? estimatedCost;
  int taskStatusId;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'jobId': jobId,
        'name': name,
        'description': description,
        'completed': completed ? 1 : 0,
        'effort_in_hours': effortInHours?.minorUnits.toInt(),
        'estimated_cost': estimatedCost?.minorUnits.toInt(),
        'task_status_id': taskStatusId,
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate.toIso8601String(),
      };

  @override
  String toString() =>
      'Task(id: $id, jobId: $jobId, name: $name, completed: $completed)';
}

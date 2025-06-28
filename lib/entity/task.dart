import 'entity.dart';
import 'task_status.dart';

/// Task entity storing status as enum but persisting only the id.
class Task extends Entity<Task> {
  Task({
    required super.id,
    required this.jobId,
    required this.name,
    required this.description,
    required this.assumption,
    required this.status,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  Task.forInsert({
    required this.jobId,
    required this.name,
    required this.description,
    required this.status,
    this.assumption = '',
  }) : super.forInsert();

  Task.forUpdate({
    required super.entity,
    required this.jobId,
    required this.name,
    required this.description,
    required this.assumption,
    required this.status,
  }) : super.forUpdate();

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'] as int,
    jobId: map['job_id'] as int,
    name: map['name'] as String,
    description: map['description'] as String,
    assumption: map['assumption'] as String,
    status: TaskStatus.fromId(map['task_status_id'] as int),
    createdDate: DateTime.parse(map['createdDate'] as String),
    modifiedDate: DateTime.parse(map['modifiedDate'] as String),
  );

  int jobId;
  String name;
  String description;
  String assumption;
  TaskStatus status;

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'job_id': jobId,
    'name': name,
    'description': description,
    'assumption': assumption,
    'task_status_id': status.id,
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
  };

  @override
  String toString() =>
      r'Task(id: $id, jobId: $jobId, name: $name, status: ${status.name}, assumption: $assumption)';
}

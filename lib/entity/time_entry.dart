import 'entity.dart';

class TimeEntry extends Entity<TimeEntry> {
  TimeEntry(
      {required super.id,
      required this.taskId,
      required this.startTime,
      required super.createdDate,
      required super.modifiedDate,
      this.endTime,
      this.note})
      : super();

  factory TimeEntry.fromMap(Map<String, dynamic> map) => TimeEntry(
        id: map['id'] as int,
        taskId: map['task_id'] as int,
        startTime: DateTime.parse(map['start_time'] as String),
        endTime: map['end_time'] != null
            ? DateTime.parse(map['end_time'] as String)
            : null,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
        note: map['notes'] as String?,
      );

  TimeEntry.forInsert(
      {required this.taskId, required this.startTime, this.note})
      : super.forInsert();

  TimeEntry.forUpdate(
      {required super.entity,
      required this.taskId,
      required this.startTime,
      this.endTime,
      this.note})
      : super.forUpdate();

  int taskId;
  DateTime startTime;
  DateTime? endTime;
  String? note;

  Duration get duration {
    final end = endTime ?? DateTime.now();

    return end.difference(startTime);
  }

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'task_id': taskId,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'created_date': createdDate.toIso8601String(),
        'modified_date': modifiedDate.toIso8601String(),
        'notes': note,
      };
}

// job_event_db.dart

// This is the DB-level entity, matching the job_event table.
import 'package:june/state_manager/src/simple/controllers.dart';

import 'entity.dart';

class JobEvent extends Entity<JobEvent> {
  JobEvent({
    required this.jobId,
    required this.startDate,
    required this.endDate,
    required super.id,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  JobEvent.forInsert({
    required this.jobId,
    required this.startDate,
    required this.endDate,
  }) : super.forInsert() {
    createdDate = DateTime.now();
    modifiedDate = DateTime.now();
  }

  JobEvent.forUpdate({
    required super.entity, // the existing primary key
    required this.jobId,
    required this.startDate,
    required this.endDate,
  }) : super.forUpdate() {
    modifiedDate = DateTime.now();
  }

  factory JobEvent.fromMap(Map<String, dynamic> map) => JobEvent(
        id: map['id'] as int,
        jobId: map['job_id'] as int,
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: DateTime.parse(map['end_date'] as String),
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'job_id': jobId,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'created_date': createdDate.toIso8601String(),
        'modified_date': modifiedDate.toIso8601String(),
      };

  int jobId;
  DateTime startDate;
  DateTime endDate;

  JobEvent copyWith({
    int? id,
    int? jobId,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdDate,
    DateTime? modifiedDate,
  }) =>
      JobEvent(
        id: id ?? this.id,
        jobId: jobId ?? this.jobId,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate ?? this.modifiedDate,
      );
}

/// Optional if you have a "JuneState" system.
class JobEventState extends JuneState {
  JobEventState();
}

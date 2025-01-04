// job_event.dart (Entity)

import 'package:june/june.dart';

import 'entity.dart';

enum JobEventStatus {
  proposed,
  confirmed,
  tentative;

  static JobEventStatus fromName(String name) {
    switch (name) {
      case 'proposed':
        return JobEventStatus.proposed;
      case 'confirmed':
        return JobEventStatus.confirmed;
      case 'tentative':
        return JobEventStatus.tentative;
      default:
        return JobEventStatus.proposed;
    }
  }
}

class JobEvent extends Entity<JobEvent> {
  JobEvent({
    required this.jobId,
    required this.start,
    required this.end,
    required super.id,
    required this.status,
    required super.createdDate,
    required super.modifiedDate,
    this.notes,
    this.noticeSentDate,
  }) : super();

  JobEvent.forInsert({
    required this.jobId,
    required this.start,
    required this.end,
    this.status = JobEventStatus.proposed, // Default status
    this.notes,
    this.noticeSentDate,
  }) : super.forInsert() {
    createdDate = DateTime.now();
    modifiedDate = DateTime.now();
  }

  JobEvent.forUpdate({
    required super.entity, // the existing primary key
    required this.jobId,
    required this.start,
    required this.end,
    this.status = JobEventStatus.proposed, // Default status
    this.notes,
    this.noticeSentDate,
  }) : super.forUpdate() {
    modifiedDate = DateTime.now();
  }

  factory JobEvent.fromMap(Map<String, dynamic> map) => JobEvent(
        id: map['id'] as int,
        jobId: map['job_id'] as int,
        start: DateTime.parse(map['start_date'] as String),
        end: DateTime.parse(map['end_date'] as String),
        status: JobEventStatus.fromName(
            map['status'] as String? ?? JobEventStatus.proposed.name),
        notes: map['notes'] as String?,
        noticeSentDate: map['notice_sent_date'] == null
            ? null
            : DateTime.parse(map['notice_sent_date'] as String),
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'job_id': jobId,
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
        'status': status.index,
        'notes': notes,
        'notice_sent_date': noticeSentDate?.toIso8601String(),
        'created_date': createdDate.toIso8601String(),
        'modified_date': modifiedDate.toIso8601String(),
      };

  int jobId;
  DateTime start;
  DateTime end;
  JobEventStatus status;
  String? notes;
  DateTime? noticeSentDate;

  JobEvent copyWith({
    int? id,
    int? jobId,
    DateTime? start,
    DateTime? end,
    JobEventStatus? status,
    String? notes,
    DateTime? noticeSentDate,
    DateTime? createdDate,
    DateTime? modifiedDate,
  }) =>
      JobEvent(
        id: id ?? this.id,
        jobId: jobId ?? this.jobId,
        start: start ?? this.start,
        end: end ?? this.end,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        noticeSentDate: noticeSentDate ?? this.noticeSentDate,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate ?? this.modifiedDate,
      );
}

/// Optional if you have a "JuneState" system.
class JobEventState extends JuneState {
  JobEventState();
}

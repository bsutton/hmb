import 'package:flutter/material.dart';
import 'package:june/june.dart';

import 'entity.dart';

enum JobActivityStatus {
  tentative(Colors.orange),
  proposed(Colors.blue),
  confirmed(Colors.green);

  const JobActivityStatus(this.color);

  final Color color;

  static JobActivityStatus fromName(String name) {
    switch (name) {
      case 'proposed':
        return JobActivityStatus.proposed;
      case 'confirmed':
        return JobActivityStatus.confirmed;
      case 'tentative':
        return JobActivityStatus.tentative;
      default:
        return JobActivityStatus.proposed;
    }
  }
}

class JobActivity extends Entity<JobActivity> {
  JobActivity({
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

  JobActivity.forInsert({
    required this.jobId,
    required this.start,
    required this.end,
    this.status = JobActivityStatus.proposed, // Default status
    this.notes,
    this.noticeSentDate,
  }) : super.forInsert() {
    createdDate = DateTime.now();
    modifiedDate = DateTime.now();
  }

  JobActivity.forUpdate({
    required super.entity, // the existing primary key
    required this.jobId,
    required this.start,
    required this.end,
    this.status = JobActivityStatus.proposed, // Default status
    this.notes,
    this.noticeSentDate,
  }) : super.forUpdate() {
    modifiedDate = DateTime.now();
  }

  factory JobActivity.fromMap(Map<String, dynamic> map) => JobActivity(
    id: map['id'] as int,
    jobId: map['job_id'] as int,
    start: DateTime.parse(map['start_date'] as String),
    end: DateTime.parse(map['end_date'] as String),
    status: JobActivityStatus.fromName(
      map['status'] as String? ?? JobActivityStatus.proposed.name,
    ),
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
    'status': status.name,
    'notes': notes,
    'notice_sent_date': noticeSentDate?.toIso8601String(),
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };

  int jobId;
  DateTime start;
  DateTime end;
  JobActivityStatus status;
  String? notes;
  DateTime? noticeSentDate;

  JobActivity copyWith({
    int? id,
    int? jobId,
    DateTime? start,
    DateTime? end,
    JobActivityStatus? status,
    String? notes,
    DateTime? noticeSentDate,
    DateTime? createdDate,
    DateTime? modifiedDate,
  }) => JobActivity(
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
class JobActivityState extends JuneState {
  JobActivityState();
}

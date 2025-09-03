/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'entity.dart';

enum JobActivityStatusColor { orange, blue, green }

enum JobActivityStatus {
  tentative(JobActivityStatusColor.orange),
  proposed(JobActivityStatusColor.blue),
  confirmed(JobActivityStatusColor.green);

  const JobActivityStatus(this.statusColour);

  final JobActivityStatusColor statusColour;

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

/// Used to hold an activity in the schedule
/// for a specific job.
class JobActivity extends Entity<JobActivity> {
  int jobId;
  DateTime start;
  DateTime end;
  JobActivityStatus status;
  String? notes;
  DateTime? noticeSentDate;

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
  }) : super.forInsert();

  JobActivity copyWith({
    int? jobId,
    DateTime? start,
    DateTime? end,
    JobActivityStatus? status,
    String? notes,
    DateTime? noticeSentDate,
  }) => JobActivity(
    id: id,
    jobId: jobId ?? this.jobId,
    start: start ?? this.start,
    end: end ?? this.end,
    status: status ?? this.status,
    notes: notes ?? this.notes,
    noticeSentDate: noticeSentDate ?? this.noticeSentDate,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

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
}

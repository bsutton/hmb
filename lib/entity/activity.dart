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

enum ActivityType {
  call,
  email,
  sms,
  visit,
  quoteFollowUp,
  scheduleUpdate,
  note,
  workDay,
}

enum ActivitySource { manual, system }

class Activity extends Entity<Activity> {
  int jobId;
  DateTime occurredAt;
  ActivityType type;
  String summary;
  String? details;
  ActivitySource source;
  int? linkedTodoId;

  Activity({
    required super.id,
    required this.jobId,
    required this.occurredAt,
    required this.type,
    required this.summary,
    required this.source,
    required super.createdDate,
    required super.modifiedDate,
    this.details,
    this.linkedTodoId,
  });

  Activity.forInsert({
    required this.jobId,
    required this.type,
    required this.summary,
    this.details,
    this.linkedTodoId,
    this.source = ActivitySource.manual,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now(),
       super.forInsert();

  Activity copyWith({
    int? jobId,
    DateTime? occurredAt,
    ActivityType? type,
    String? summary,
    String? details,
    ActivitySource? source,
    int? linkedTodoId,
  }) => Activity(
    id: id,
    jobId: jobId ?? this.jobId,
    occurredAt: occurredAt ?? this.occurredAt,
    type: type ?? this.type,
    summary: summary ?? this.summary,
    details: details ?? this.details,
    source: source ?? this.source,
    linkedTodoId: linkedTodoId ?? this.linkedTodoId,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory Activity.fromMap(Map<String, dynamic> map) => Activity(
    id: map['id'] as int,
    jobId: map['job_id'] as int,
    occurredAt: DateTime.parse(map['occurred_at'] as String),
    type: ActivityType.values.firstWhere(
      (e) => e.name == (map['type'] as String?),
      orElse: () => ActivityType.note,
    ),
    summary: map['summary'] as String? ?? '',
    details: map['details'] as String?,
    source: ActivitySource.values.firstWhere(
      (e) => e.name == (map['source'] as String?),
      orElse: () => ActivitySource.manual,
    ),
    linkedTodoId: map['linked_todo_id'] as int?,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'job_id': jobId,
    'occurred_at': occurredAt.toIso8601String(),
    'type': type.name,
    'summary': summary,
    'details': details,
    'source': source.name,
    'linked_todo_id': linkedTodoId,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

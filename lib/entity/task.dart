/*
 * Copyright © OnePub IP Pty Ltd.
 * S. Brett Sutton. All Rights Reserved.
 *
 * Note: This software is licensed under the GNU General Public License,
 *       with the following exceptions:
 *   • Permitted for internal use within your own business or organization only.
 *   • Any external distribution, resale, or incorporation into products
 *     for third parties is strictly prohibited.
 *
 * See the full license on GitHub:
 * https://github.com/bsutton/hmb/blob/main/LICENSE
 */

import 'entity.dart';
import 'job.dart'; // for BillingType
import 'task_status.dart';

/// A Job Task which we use to track time and materials against.
class Task extends Entity<Task> {
  int jobId;
  String name;
  String description;
  String assumption;

  /// Notes not shown to customers; editable even after quote approval.
  String internalNotes;

  /// Optional override. When null, inherit from Job.billingType.
  BillingType? billingType;

  TaskStatus status;

  Task._({
    required super.id,
    required this.jobId,
    required this.name,
    required this.description,
    required this.assumption,
    required this.internalNotes,
    required this.status,
    required super.createdDate,
    required super.modifiedDate,
    this.billingType,
  }) : super();

  Task.forInsert({
    required this.jobId,
    required this.name,
    required this.description,
    required this.status,
    this.assumption = '',
    this.internalNotes = '',
    this.billingType,
  }) : super.forInsert();

  Task copyWith({
    int? jobId,
    String? name,
    String? description,
    String? assumption,
    String? internalNotes,
    TaskStatus? status,
    BillingType? billingType,
  }) => Task._(
    id: id,
    jobId: jobId ?? this.jobId,
    name: name ?? this.name,
    description: description ?? this.description,
    assumption: assumption ?? this.assumption,
    internalNotes: internalNotes ?? this.internalNotes,
    status: status ?? this.status,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
    billingType: billingType ?? this.billingType,
  );

  /// Resolve the effective billing type for this task.
  BillingType effectiveBillingType(BillingType jobBillingType) =>
      billingType ?? jobBillingType;

  factory Task.fromMap(Map<String, dynamic> map) => Task._(
    id: map['id'] as int,
    jobId: map['job_id'] as int,
    name: map['name'] as String,
    description: map['description'] as String? ?? '',
    assumption: map['assumption'] as String? ?? '',
    internalNotes: map['internal_notes'] as String? ?? '',
    status: TaskStatus.fromId(map['task_status_id'] as int),
    createdDate: DateTime.parse(map['createdDate'] as String),
    modifiedDate: DateTime.parse(map['modifiedDate'] as String),
    billingType: (map['billing_type'] as String?) == null
        ? null
        : BillingType.fromName(map['billing_type'] as String?),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'job_id': jobId,
    'name': name,
    'description': description,
    'assumption': assumption,
    'internal_notes': internalNotes,
    'task_status_id': status.id,
    'billing_type': billingType?.name,
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
  };

  @override
  String toString() =>
      'Task(id: $id, jobId: $jobId, name: $name, status: ${status.name}, '
      'assumption: $assumption, internalNotes: $internalNotes, '
      'billingType: ${billingType?.name})';
}

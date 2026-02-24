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

enum TaskApprovalStatus {
  unsent(0),
  sent(1),
  modified(2);

  const TaskApprovalStatus(this.ordinal);

  final int ordinal;
}

class TaskApproval extends Entity<TaskApproval> {
  int jobId;
  int contactId;
  TaskApprovalStatus status;

  TaskApproval({
    required super.id,
    required this.jobId,
    required this.contactId,
    required this.status,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  TaskApproval.forInsert({
    required this.jobId,
    required this.contactId,
    this.status = TaskApprovalStatus.unsent,
  }) : super.forInsert();

  TaskApproval copyWith({
    int? jobId,
    int? contactId,
    TaskApprovalStatus? status,
  }) => TaskApproval(
    id: id,
    jobId: jobId ?? this.jobId,
    contactId: contactId ?? this.contactId,
    status: status ?? this.status,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory TaskApproval.fromMap(Map<String, dynamic> m) => TaskApproval(
    id: m['id'] as int,
    jobId: m['job_id'] as int,
    contactId: m['contact_id'] as int,
    status: TaskApprovalStatus.values[m['status'] as int],
    createdDate: DateTime.parse(m['created_date'] as String),
    modifiedDate: DateTime.parse(m['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'job_id': jobId,
    'contact_id': contactId,
    'status': status.ordinal,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

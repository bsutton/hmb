/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'entity.dart';

enum TaskApprovalDecision {
  pending(0),
  approved(1),
  rejected(2);

  const TaskApprovalDecision(this.ordinal);

  final int ordinal;
}

class TaskApprovalTask extends Entity<TaskApprovalTask> {
  int approvalId;
  int taskId;
  TaskApprovalDecision status;

  TaskApprovalTask._({
    required super.id,
    required this.approvalId,
    required this.taskId,
    required this.status,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  TaskApprovalTask.forInsert({
    required this.approvalId,
    required this.taskId,
    this.status = TaskApprovalDecision.pending,
  }) : super.forInsert();

  TaskApprovalTask copyWith({
    int? approvalId,
    int? taskId,
    TaskApprovalDecision? status,
  }) => TaskApprovalTask._(
    id: id,
    approvalId: approvalId ?? this.approvalId,
    taskId: taskId ?? this.taskId,
    status: status ?? this.status,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory TaskApprovalTask.fromMap(Map<String, dynamic> map) =>
      TaskApprovalTask._(
        id: map['id'] as int,
        approvalId: map['approval_id'] as int,
        taskId: map['task_id'] as int,
        status: TaskApprovalDecision.values[map['status'] as int],
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'approval_id': approvalId,
    'task_id': taskId,
    'status': status.ordinal,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

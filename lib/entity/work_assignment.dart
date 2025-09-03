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

enum WorkAssignmentStatus {
  // the work assignment hasn't been emailed to the supplier.
  unsent(0),
  // the work assignment has been emailed to the supplier.
  sent(1),
  // the work assignment has been modified since it was last
  // sent to the supplier.
  modified(2);

  const WorkAssignmentStatus(this.ordinal);

  final int ordinal;
}

class WorkAssignment extends Entity<WorkAssignment> {
  int jobId;
  int supplierId;
  int contactId;
  WorkAssignmentStatus status;

  WorkAssignment({
    required super.id,
    required this.jobId,
    required this.supplierId,
    required this.contactId,
    required this.status,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  /// For inserts, status defaults to unsent.
  WorkAssignment.forInsert({
    required this.jobId,
    required this.supplierId,
    required this.contactId,
    this.status = WorkAssignmentStatus.unsent,
  }) : super.forInsert();

  WorkAssignment copyWith({
    int? jobId,
    int? supplierId,
    int? contactId,
    WorkAssignmentStatus? status,
  }) => WorkAssignment(
    id: id,
    jobId: jobId ?? this.jobId,
    supplierId: supplierId ?? this.supplierId,
    contactId: contactId ?? this.contactId,
    status: status ?? this.status,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory WorkAssignment.fromMap(Map<String, dynamic> m) => WorkAssignment(
    id: m['id'] as int,
    jobId: m['job_id'] as int,
    supplierId: m['supplier_id'] as int,
    contactId: m['contact_id'] as int,
    status: WorkAssignmentStatus.values[m['status'] as int],
    createdDate: DateTime.parse(m['created_date'] as String),
    modifiedDate: DateTime.parse(m['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'job_id': jobId,
    'supplier_id': supplierId,
    'contact_id': contactId,
    'status': status.ordinal,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

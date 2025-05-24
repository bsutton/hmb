// lib/src/entity/supplier_assignment.dart

import 'entity.dart';

class SupplierAssignment extends Entity<SupplierAssignment> {
  SupplierAssignment({
    required super.id,
    required this.jobId,
    required this.supplierId,
    required this.contactId,
    required this.sent,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  /// For inserts, `sent` defaults to false.
  SupplierAssignment.forInsert({
    required this.jobId,
    required this.supplierId,
    required this.contactId,
    this.sent = false,
  }) : super.forInsert() {
    createdDate = DateTime.now();
    modifiedDate = DateTime.now();
  }

  SupplierAssignment.forUpdate({
    required super.entity,
    required this.jobId,
    required this.supplierId,
    required this.contactId,
    bool? sent,
  }) : sent = sent ?? (entity as SupplierAssignment).sent,
       super.forUpdate() {
    modifiedDate = DateTime.now();
  }

  factory SupplierAssignment.fromMap(Map<String, dynamic> m) =>
      SupplierAssignment(
        id: m['id'] as int,
        jobId: m['job_id'] as int,
        supplierId: m['supplier_id'] as int,
        contactId: m['contact_id'] as int,
        sent: (m['sent'] as int) == 1,
        createdDate: DateTime.parse(m['created_date'] as String),
        modifiedDate: DateTime.parse(m['modified_date'] as String),
      );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'job_id': jobId,
    'supplier_id': supplierId,
    'contact_id': contactId,
    'sent': sent ? 1 : 0,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };

  int jobId;
  int supplierId;
  int contactId;
  bool sent;
}

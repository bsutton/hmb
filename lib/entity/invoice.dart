import 'package:money2/money2.dart';

import 'entity.dart';

class Invoice extends Entity<Invoice> {
  Invoice({
    required super.id,
    required this.jobId,
    required this.totalAmount,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  Invoice.forInsert({
    required this.jobId,
    required this.totalAmount,
  }) : super.forInsert();

  Invoice.forUpdate({
    required super.entity,
    required this.jobId,
    required this.totalAmount,
  }) : super.forUpdate();

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice(
        id: map['id'] as int,
        jobId: map['job_id'] as int,
        totalAmount: Money.fromInt(map['total_amount'] as int, isoCode: 'AUD'),
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  int jobId;
  Money totalAmount;

  Invoice copyWith({
    int? id,
    int? jobId,
    Money? totalAmount,
    DateTime? createdDate,
    DateTime? modifiedDate,
  }) =>
      Invoice(
        id: id ?? this.id,
        jobId: jobId ?? this.jobId,
        totalAmount: totalAmount ?? this.totalAmount,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate ?? this.modifiedDate,
      );

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'job_id': jobId,
        'total_amount': totalAmount.minorUnits.toInt(),
        'created_date': createdDate.toIso8601String(),
        'modified_date': modifiedDate.toIso8601String(),
      };
}

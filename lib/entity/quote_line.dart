import 'package:money2/money2.dart';

import 'entity.dart';
import 'invoice_line.dart';

enum LineApprovalStatus { preApproval, approved, rejected }

class QuoteLine extends Entity<QuoteLine> {
  QuoteLine({
    required super.id,
    required this.quoteId,
    required this.description,
    required this.quantity,
    required this.unitCharge,
    required this.lineTotal,
    required this.taskId,
    required super.createdDate,
    required super.modifiedDate,
    this.quoteLineGroupId,
    this.lineChargeableStatus = LineChargeableStatus.normal,
    this.lineApprovalStatus = LineApprovalStatus.preApproval,
  }) : super();

  QuoteLine.forInsert({
    required this.quoteId,
    required this.taskId,
    required this.description,
    required this.quantity,
    required this.unitCharge,
    required this.lineTotal,
    this.quoteLineGroupId,
    this.lineChargeableStatus = LineChargeableStatus.normal,
    this.lineApprovalStatus = LineApprovalStatus.preApproval,
  }) : super.forInsert();

  QuoteLine.forUpdate({
    required super.entity,
    required this.quoteId,
    required this.taskId,
    required this.description,
    required this.quantity,
    required this.unitCharge,
    required this.lineTotal,
    this.quoteLineGroupId,
    this.lineChargeableStatus = LineChargeableStatus.normal,
    this.lineApprovalStatus = LineApprovalStatus.preApproval,
  }) : super.forUpdate();

  factory QuoteLine.fromMap(Map<String, dynamic> map) => QuoteLine(
    id: map['id'] as int,
    quoteId: map['quote_id'] as int,
    taskId: map['task_id'] as int?,
    quoteLineGroupId: map['quote_line_group_id'] as int?,
    description: map['description'] as String,
    quantity: Fixed.fromInt(map['quantity'] as int),
    unitCharge: Money.fromInt(map['unit_charge'] as int, isoCode: 'AUD'),
    lineTotal: Money.fromInt(map['line_total'] as int, isoCode: 'AUD'),
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
    lineChargeableStatus: LineChargeableStatus.values.byName(
      map['line_chargeable_status'] as String,
    ),
    lineApprovalStatus: LineApprovalStatus.values.byName(
      map['line_approval_status'] as String,
    ),
  );

  int quoteId;
  int? taskId;
  int? quoteLineGroupId;
  String description;
  Fixed quantity;
  Money unitCharge;
  Money lineTotal;
  LineChargeableStatus lineChargeableStatus;
  LineApprovalStatus lineApprovalStatus;

  QuoteLine copyWith({
    int? id,
    int? quoteId,
    int? taskId,
    int? quoteLineGroupId,
    String? description,
    Fixed? quantity,
    Money? unitCharge,
    Money? lineTotal,
    DateTime? createdDate,
    DateTime? modifiedDate,
    LineChargeableStatus? lineChargeableStatus,
    LineApprovalStatus? lineApprovalStatus,
  }) => QuoteLine(
    id: id ?? this.id,
    quoteId: quoteId ?? this.quoteId,
    taskId: taskId ?? this.taskId,
    quoteLineGroupId: quoteLineGroupId ?? this.quoteLineGroupId,
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    unitCharge: unitCharge ?? this.unitCharge,
    lineTotal: lineTotal ?? this.lineTotal,
    createdDate: createdDate ?? this.createdDate,
    modifiedDate: modifiedDate ?? this.modifiedDate,
    lineApprovalStatus: lineApprovalStatus ?? this.lineApprovalStatus,
    lineChargeableStatus: lineChargeableStatus ?? this.lineChargeableStatus,
  );
  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'quote_id': quoteId,
    'task_id': taskId,
    'quote_line_group_id': quoteLineGroupId,
    'description': description,
    'quantity': quantity.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'unit_charge': unitCharge.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'line_total': lineTotal.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'line_chargeable_status': lineChargeableStatus.name,
    'line_approval_status': lineApprovalStatus.name,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

// lib/entity/quote_line.dart

import 'package:money2/money2.dart';

import 'entity.dart';
import 'invoice_line.dart';


class QuoteLine extends Entity<QuoteLine> {
  QuoteLine({
    required super.id,
    required this.quoteId,
    required this.description,
    required this.quantity,
    required this.unitCharge,
    required this.lineTotal,
    required super.createdDate,
    required super.modifiedDate,
    this.quoteLineGroupId,
    this.lineChargeableStatus = LineChargeableStatus.normal,
  }) : super();

  QuoteLine.forInsert({
    required this.quoteId,
    required this.description,
    required this.quantity,
    required this.unitCharge,
    required this.lineTotal,
    this.quoteLineGroupId,
    this.lineChargeableStatus = LineChargeableStatus.normal,
  }) : super.forInsert();

  QuoteLine.forUpdate({
    required super.entity,
    required this.quoteId,
    required this.description,
    required this.quantity,
    required this.unitCharge,
    required this.lineTotal,
    this.quoteLineGroupId,
    this.lineChargeableStatus = LineChargeableStatus.normal,
  }) : super.forUpdate();

  factory QuoteLine.fromMap(Map<String, dynamic> map) => QuoteLine(
    id: map['id'] as int,
    quoteId: map['quote_id'] as int,
    quoteLineGroupId: map['quote_line_group_id'] as int?,
    description: map['description'] as String,
    quantity: Fixed.fromInt(map['quantity'] as int),
    unitCharge: Money.fromInt(map['unit_charge'] as int, isoCode: 'AUD'),
    lineTotal: Money.fromInt(map['line_total'] as int, isoCode: 'AUD'),
    lineChargeableStatus: LineChargeableStatus.values.byName(
      map['line_chargeable_status'] as String,
    ),
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  int quoteId;
  int? quoteLineGroupId;
  String description;
  Fixed quantity;
  Money unitCharge;
  Money lineTotal;
  LineChargeableStatus lineChargeableStatus;

  QuoteLine copyWith({
    int? id,
    int? quoteId,
    int? quoteLineGroupId,
    String? description,
    Fixed? quantity,
    Money? unitCharge,
    Money? lineTotal,
    LineChargeableStatus? lineChargeableStatus,
    DateTime? createdDate,
    DateTime? modifiedDate,
  }) => QuoteLine(
    id: id ?? this.id,
    quoteId: quoteId ?? this.quoteId,
    quoteLineGroupId: quoteLineGroupId ?? this.quoteLineGroupId,
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    unitCharge: unitCharge ?? this.unitCharge,
    lineTotal: lineTotal ?? this.lineTotal,
    lineChargeableStatus: lineChargeableStatus ?? this.lineChargeableStatus,
    createdDate: createdDate ?? this.createdDate,
    modifiedDate: modifiedDate ?? this.modifiedDate,
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'quote_id': quoteId,
    'quote_line_group_id': quoteLineGroupId,
    'description': description,
    'quantity': quantity.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'unit_charge': unitCharge.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'line_total': lineTotal.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'line_chargeable_status': lineChargeableStatus.name,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

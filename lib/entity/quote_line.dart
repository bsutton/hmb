import 'package:money2/money2.dart';
import 'entity.dart';
import 'invoice_line.dart';

class QuoteLine extends Entity<QuoteLine> {
  QuoteLine({
    required super.id,
    required this.quoteId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required super.createdDate,
    required super.modifiedDate,
    this.quoteLineGroupId,
    this.status = LineStatus.normal,
  }) : super();

  QuoteLine.forInsert({
    required this.quoteId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.quoteLineGroupId,
    this.status = LineStatus.normal,
  }) : super.forInsert();

  QuoteLine.forUpdate({
    required super.entity,
    required this.quoteId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.quoteLineGroupId,
    this.status = LineStatus.normal,
  }) : super.forUpdate();

  factory QuoteLine.fromMap(Map<String, dynamic> map) => QuoteLine(
    id: map['id'] as int,
    quoteId: map['quote_id'] as int,
    quoteLineGroupId: map['quote_line_group_id'] as int?,
    description: map['description'] as String,
    quantity: Fixed.fromInt(map['quantity'] as int),
    unitPrice: Money.fromInt(map['unit_price'] as int, isoCode: 'AUD'),
    lineTotal: Money.fromInt(map['line_total'] as int, isoCode: 'AUD'),
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
    status: LineStatus.values[map['status'] as int? ?? LineStatus.normal.index],
  );

  int quoteId;
  int? quoteLineGroupId;
  String description;
  Fixed quantity;
  Money unitPrice;
  Money lineTotal;
  LineStatus status;

  QuoteLine copyWith({
    int? id,
    int? quoteId,
    int? quoteLineGroupId,
    String? description,
    Fixed? quantity,
    Money? unitPrice,
    Money? lineTotal,
    DateTime? createdDate,
    DateTime? modifiedDate,
    LineStatus? status,
  }) => QuoteLine(
    id: id ?? this.id,
    quoteId: quoteId ?? this.quoteId,
    quoteLineGroupId: quoteLineGroupId ?? this.quoteLineGroupId,
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    lineTotal: lineTotal ?? this.lineTotal,
    createdDate: createdDate ?? this.createdDate,
    modifiedDate: modifiedDate ?? this.modifiedDate,
    status: status ?? this.status,
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'quote_id': quoteId,
    'quote_line_group_id': quoteLineGroupId,
    'description': description,
    'quantity': quantity.copyWith(scale: 2).minorUnits.toInt(),
    'unit_price': unitPrice.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'line_total': lineTotal.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
    'status': status.index,
  };
}

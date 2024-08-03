import 'package:money2/money2.dart';

import '../invoicing/xero/models/models.dart';
import 'entity.dart';

enum LineStatus { 
  /// The line item is chargable
  normal, 
  /// The line item will be show but the amount will be 0
  noCharge, 
  /// The line item is to be removed from this invoice
  /// and made available to be billed on a later invoice.
  excluded, 
  
  /// The line item is not chargable and will be hidden from the user
  noChargeHidden }

class InvoiceLine extends Entity<InvoiceLine> {
  InvoiceLine({
    required super.id,
    required this.invoiceId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required super.createdDate,
    required super.modifiedDate,
    this.invoiceLineGroupId,
    this.status = LineStatus.normal,
  }) : super();

  InvoiceLine.forInsert({
    required this.invoiceId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.invoiceLineGroupId,
    this.status = LineStatus.normal,
  }) : super.forInsert();

  InvoiceLine.forUpdate({
    required super.entity,
    required this.invoiceId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.invoiceLineGroupId,
    this.status = LineStatus.normal,
  }) : super.forUpdate();

  factory InvoiceLine.fromMap(Map<String, dynamic> map) => InvoiceLine(
      id: map['id'] as int,
      invoiceId: map['invoice_id'] as int,
      invoiceLineGroupId: map['invoice_line_group_id'] as int?,
      description: map['description'] as String,
      quantity: Fixed.fromInt(map['quantity'] as int),
      unitPrice: Money.fromInt(map['unit_price'] as int, isoCode: 'AUD'),
      lineTotal: Money.fromInt(map['line_total'] as int, isoCode: 'AUD'),
      createdDate: DateTime.parse(map['created_date'] as String),
      modifiedDate: DateTime.parse(map['modified_date'] as String),
      status:
          LineStatus.values[map['status'] as int? ?? LineStatus.normal.index]);

  int invoiceId;
  int? invoiceLineGroupId;
  String description;
  Fixed quantity;
  Money unitPrice;
  Money lineTotal;
  LineStatus status;

  InvoiceLine copyWith({
    int? id,
    int? invoiceId,
    int? invoiceLineGroupId,
    String? description,
    Fixed? quantity,
    Money? unitPrice,
    Money? lineTotal,
    DateTime? createdDate,
    DateTime? modifiedDate,
    LineStatus? status,
  }) =>
      InvoiceLine(
        id: id ?? this.id,
        invoiceId: invoiceId ?? this.invoiceId,
        invoiceLineGroupId: invoiceLineGroupId ?? this.invoiceLineGroupId,
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
        'invoice_id': invoiceId,
        'invoice_line_group_id': invoiceLineGroupId,
        'description': description,
        'quantity': quantity.minorUnits.toInt(),
        'unit_price': unitPrice.minorUnits.toInt(),
        'line_total': lineTotal.minorUnits.toInt(),
        'created_date': createdDate.toIso8601String(),
        'modified_date': modifiedDate.toIso8601String(),
        'status': status.index,
      };

  XeroLineItem toXeroLineItem() => XeroLineItem(
      description: description,
      quantity: quantity,
      unitAmount: unitPrice,
      lineTotal: lineTotal,
      // TODO(bsutton): fix these so that they can be configured from the system
      /// table.
      accountCode: '240', // 240 - Handyman income',
      itemCode: 'IHS-Labour');
}

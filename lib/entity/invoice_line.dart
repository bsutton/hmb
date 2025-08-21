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

import 'package:money2/money2.dart';

import '../api/xero/models/xero_line_item.dart';
import 'entity.dart';

enum LineChargeableStatus {
  /// The line item is chargable
  normal('Chargable'),

  /// The line item will be show but the amount will be 0
  noCharge('No Charge'),

  /// The line item is not chargable and will be hidden from the user
  noChargeHidden('No Charge and Hidden');

  const LineChargeableStatus(this.description);

  final String description;
}

class InvoiceLine extends Entity<InvoiceLine> {
  int invoiceId;
  int invoiceLineGroupId;
  String description;
  Fixed quantity;
  Money unitPrice;
  Money lineTotal;
  LineChargeableStatus status;
  bool fromBookingFee;

  InvoiceLine({
    required super.id,
    required this.invoiceId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required super.createdDate,
    required super.modifiedDate,
    required this.invoiceLineGroupId,
    this.status = LineChargeableStatus.normal,
    this.fromBookingFee = false,
  }) : super();

  InvoiceLine.forInsert({
    required this.invoiceId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.invoiceLineGroupId,
    this.status = LineChargeableStatus.normal,
    this.fromBookingFee = false,
  }) : super.forInsert();

  InvoiceLine.forUpdate({
    required super.entity,
    required this.invoiceId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.invoiceLineGroupId,
    this.status = LineChargeableStatus.normal,
    this.fromBookingFee = false,
  }) : super.forUpdate();

  factory InvoiceLine.fromMap(Map<String, dynamic> map) => InvoiceLine(
    id: map['id'] as int,
    invoiceId: map['invoice_id'] as int,
    invoiceLineGroupId: map['invoice_line_group_id'] as int,
    description: map['description'] as String,
    quantity: Fixed.fromInt(map['quantity'] as int),
    unitPrice: Money.fromInt(map['unit_price'] as int, isoCode: 'AUD'),
    lineTotal: Money.fromInt(map['line_total'] as int, isoCode: 'AUD'),
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
    status: LineChargeableStatus
        .values[map['status'] as int? ?? LineChargeableStatus.normal.index],
    fromBookingFee: map['from_booking_fee'] == 1,
  );

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
    LineChargeableStatus? status,
    bool? fromBookingFee,
  }) => InvoiceLine(
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
    fromBookingFee: fromBookingFee ?? this.fromBookingFee,
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'invoice_id': invoiceId,
    'invoice_line_group_id': invoiceLineGroupId,
    'description': description,
    'quantity': quantity.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'unit_price': unitPrice.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'line_total': lineTotal.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
    'status': status.index,
    'from_booking_fee': fromBookingFee ? 1 : 0,
  };

  XeroLineItem toXeroLineItem({
    required String accountCode,
    required String itemCode,
  }) => XeroLineItem(
    description: description,
    quantity: quantity,
    unitAmount: unitPrice,
    lineTotal: lineTotal,
    accountCode: accountCode, // '240',
    itemCode: itemCode, // 'IHS-Labour',
  );
}

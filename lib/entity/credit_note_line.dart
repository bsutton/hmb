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

import 'package:money2/money2.dart';

import 'entity.dart';

class CreditNoteLine extends Entity<CreditNoteLine> {
  int creditNoteId;
  String description;
  Fixed quantity;
  Money unitPrice;
  Money lineTotal;
  Money taxAmount;
  String? incomeAccountCode;
  String? taxType;

  CreditNoteLine({
    required super.id,
    required this.creditNoteId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.taxAmount,
    required super.createdDate,
    required super.modifiedDate,
    this.incomeAccountCode,
    this.taxType,
  }) : super();

  CreditNoteLine.forInsert({
    required this.creditNoteId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    Money? taxAmount,
    this.incomeAccountCode,
    this.taxType,
  }) : taxAmount = taxAmount ?? Money.fromInt(0, isoCode: 'AUD'),
       super.forInsert();

  factory CreditNoteLine.fromMap(Map<String, dynamic> map) => CreditNoteLine(
    id: map['id'] as int,
    creditNoteId: map['credit_note_id'] as int,
    description: map['description'] as String,
    quantity: Fixed.fromInt(map['quantity'] as int),
    unitPrice: Money.fromInt(map['unit_price'] as int, isoCode: 'AUD'),
    lineTotal: Money.fromInt(map['line_total'] as int, isoCode: 'AUD'),
    taxAmount: Money.fromInt(map['tax_amount'] as int? ?? 0, isoCode: 'AUD'),
    incomeAccountCode: map['income_account_code'] as String?,
    taxType: map['tax_type'] as String?,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'credit_note_id': creditNoteId,
    'description': description,
    'quantity': quantity.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'unit_price': unitPrice.minorUnits.toInt(),
    'line_total': lineTotal.minorUnits.toInt(),
    'tax_amount': taxAmount.minorUnits.toInt(),
    'income_account_code': incomeAccountCode,
    'tax_type': taxType,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

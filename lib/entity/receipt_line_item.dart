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

import '../util/dart/money_ex.dart';
import 'entity.dart';

class ReceiptLineItem extends Entity<ReceiptLineItem> {
  final int receiptId;
  final String description;
  final double quantity;
  final Money unitPrice;
  final Money lineTotalExTax;
  final Money taxAmount;
  final Money lineTotalIncTax;
  final int? matchedTaskItemId;
  final int confidence;
  final String source;

  ReceiptLineItem({
    required super.id,
    required this.receiptId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotalExTax,
    required this.taxAmount,
    required this.lineTotalIncTax,
    required this.matchedTaskItemId,
    required this.confidence,
    required this.source,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  ReceiptLineItem.forInsert({
    required this.receiptId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotalExTax,
    required this.taxAmount,
    required this.lineTotalIncTax,
    required this.matchedTaskItemId,
    required this.confidence,
    required this.source,
  }) : super.forInsert();

  factory ReceiptLineItem.fromMap(Map<String, dynamic> map) => ReceiptLineItem(
    id: map['id'] as int,
    receiptId: map['receipt_id'] as int,
    description: map['description'] as String,
    quantity: (map['quantity'] as num).toDouble(),
    unitPrice: MoneyEx.fromInt(map['unit_price'] as int?),
    lineTotalExTax: MoneyEx.fromInt(map['line_total_ex_tax'] as int?),
    taxAmount: MoneyEx.fromInt(map['tax_amount'] as int?),
    lineTotalIncTax: MoneyEx.fromInt(map['line_total_inc_tax'] as int?),
    matchedTaskItemId: map['matched_task_item_id'] as int?,
    confidence: map['confidence'] as int? ?? 0,
    source: map['source'] as String? ?? 'manual',
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'receipt_id': receiptId,
    'description': description,
    'quantity': quantity,
    'unit_price': unitPrice.minorUnits.toInt(),
    'line_total_ex_tax': lineTotalExTax.minorUnits.toInt(),
    'tax_amount': taxAmount.minorUnits.toInt(),
    'line_total_inc_tax': lineTotalIncTax.minorUnits.toInt(),
    'matched_task_item_id': matchedTaskItemId,
    'confidence': confidence,
    'source': source,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

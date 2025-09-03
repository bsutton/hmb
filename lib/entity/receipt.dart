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

// lib/src/entity/receipt.dart
import 'package:money2/money2.dart';

import 'entity.dart';

class Receipt extends Entity<Receipt> {
  final DateTime receiptDate;
  final int jobId;
  final int supplierId;
  final Money totalExcludingTax; // stored as cents
  final Money tax; // stored as cents
  final Money totalIncludingTax; // stored as cents

  Receipt({
    required super.id,
    required this.receiptDate,
    required this.jobId,
    required this.supplierId,
    required this.totalExcludingTax,
    required this.tax,
    required this.totalIncludingTax,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  Receipt.forInsert({
    required this.receiptDate,
    required this.jobId,
    required this.supplierId,
    required this.totalExcludingTax,
    required this.tax,
    required this.totalIncludingTax,
  }) : super.forInsert();

  Receipt copyWith({
    DateTime? receiptDate,
    int? jobId,
    int? supplierId,
    Money? totalExcludingTax,
    Money? tax,
    Money? totalIncludingTax,
  }) => Receipt(
    id: id,
    receiptDate: receiptDate ?? this.receiptDate,
    jobId: jobId ?? this.jobId,
    supplierId: supplierId ?? this.supplierId,
    totalExcludingTax: totalExcludingTax ?? this.totalExcludingTax,
    tax: tax ?? this.tax,
    totalIncludingTax: totalIncludingTax ?? this.totalIncludingTax,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory Receipt.fromMap(Map<String, dynamic> map) => Receipt(
    id: map['id'] as int,
    receiptDate: DateTime.parse(map['receipt_date'] as String),
    jobId: map['job_id'] as int,
    supplierId: map['supplier_id'] as int,
    totalExcludingTax: Money.fromInt(
      map['total_excluding_tax'] as int,
      isoCode: 'AUD',
    ),
    tax: Money.fromInt(map['tax'] as int, isoCode: 'AUD'),
    totalIncludingTax: Money.fromInt(
      map['total_including_tax'] as int,
      isoCode: 'AUD',
    ),
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'receipt_date': receiptDate.toIso8601String(),
    'job_id': jobId,
    'supplier_id': supplierId,
    'total_excluding_tax': totalExcludingTax.minorUnits.toInt(),
    'tax': tax.minorUnits.toInt(),
    'total_including_tax': totalIncludingTax.minorUnits.toInt(),
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

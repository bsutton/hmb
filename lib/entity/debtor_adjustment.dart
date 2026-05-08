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

enum DebtorAdjustmentType {
  rounding(0),
  writeOff(1),
  badDebt(2),
  correction(3),
  openingBalance(4),
  other(5);

  final int ordinal;
  const DebtorAdjustmentType(this.ordinal);

  static DebtorAdjustmentType fromOrdinal(int? value) =>
      DebtorAdjustmentType.values.firstWhere(
        (type) => type.ordinal == value,
        orElse: () => DebtorAdjustmentType.other,
      );
}

class DebtorAdjustment extends Entity<DebtorAdjustment> {
  int? customerId;
  int? contactId;
  int? jobId;
  int? invoiceId;
  DebtorAdjustmentType adjustmentType;
  DateTime adjustmentDate;
  Money amount;
  String reason;
  String? notes;

  DebtorAdjustment({
    required super.id,
    required this.customerId,
    required this.contactId,
    required this.jobId,
    required this.invoiceId,
    required this.adjustmentType,
    required this.adjustmentDate,
    required this.amount,
    required this.reason,
    required super.createdDate,
    required super.modifiedDate,
    this.notes,
  }) : super();

  DebtorAdjustment.forInsert({
    required this.customerId,
    required this.contactId,
    required this.jobId,
    required this.invoiceId,
    required this.adjustmentType,
    required this.adjustmentDate,
    required this.amount,
    required this.reason,
    this.notes,
  }) : super.forInsert();

  factory DebtorAdjustment.fromMap(Map<String, dynamic> map) =>
      DebtorAdjustment(
        id: map['id'] as int,
        customerId: map['customer_id'] as int?,
        contactId: map['contact_id'] as int?,
        jobId: map['job_id'] as int?,
        invoiceId: map['invoice_id'] as int?,
        adjustmentType: DebtorAdjustmentType.fromOrdinal(
          map['adjustment_type'] as int?,
        ),
        adjustmentDate: DateTime.parse(map['adjustment_date'] as String),
        amount: Money.fromInt(map['amount'] as int, isoCode: 'AUD'),
        reason: map['reason'] as String,
        notes: map['notes'] as String?,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'customer_id': customerId,
    'contact_id': contactId,
    'job_id': jobId,
    'invoice_id': invoiceId,
    'adjustment_type': adjustmentType.ordinal,
    'adjustment_date': adjustmentDate.toIso8601String(),
    'amount': amount.minorUnits.toInt(),
    'reason': reason,
    'notes': notes,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

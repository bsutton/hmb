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

class CreditAllocation extends Entity<CreditAllocation> {
  int creditNoteId;
  int invoiceId;
  Money amount;
  DateTime allocatedDate;
  String? externalAllocationId;

  CreditAllocation({
    required super.id,
    required this.creditNoteId,
    required this.invoiceId,
    required this.amount,
    required this.allocatedDate,
    required super.createdDate,
    required super.modifiedDate,
    this.externalAllocationId,
  }) : super();

  CreditAllocation.forInsert({
    required this.creditNoteId,
    required this.invoiceId,
    required this.amount,
    required this.allocatedDate,
    this.externalAllocationId,
  }) : super.forInsert();

  CreditAllocation copyWith({String? externalAllocationId}) => CreditAllocation(
    id: id,
    creditNoteId: creditNoteId,
    invoiceId: invoiceId,
    amount: amount,
    allocatedDate: allocatedDate,
    externalAllocationId: externalAllocationId ?? this.externalAllocationId,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory CreditAllocation.fromMap(Map<String, dynamic> map) =>
      CreditAllocation(
        id: map['id'] as int,
        creditNoteId: map['credit_note_id'] as int,
        invoiceId: map['invoice_id'] as int,
        amount: Money.fromInt(map['amount'] as int, isoCode: 'AUD'),
        allocatedDate: DateTime.parse(map['allocated_date'] as String),
        externalAllocationId: map['external_allocation_id'] as String?,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'credit_note_id': creditNoteId,
    'invoice_id': invoiceId,
    'amount': amount.minorUnits.toInt(),
    'allocated_date': allocatedDate.toIso8601String(),
    'external_allocation_id': externalAllocationId,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

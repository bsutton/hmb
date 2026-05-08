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

enum CreditNoteStatus {
  draft(0),
  approved(1),
  partiallyAllocated(2),
  allocated(3),
  voided(4);

  final int ordinal;
  const CreditNoteStatus(this.ordinal);

  static CreditNoteStatus fromOrdinal(int? value) =>
      CreditNoteStatus.values.firstWhere(
        (status) => status.ordinal == value,
        orElse: () => CreditNoteStatus.draft,
      );
}

class CreditNote extends Entity<CreditNote> {
  int? customerId;
  int? contactId;
  int? jobId;
  int? relatedInvoiceId;
  String? creditNoteNum;
  String? externalCreditNoteId;
  DateTime creditDate;
  Money totalAmount;
  CreditNoteStatus status;
  String? reason;

  CreditNote({
    required super.id,
    required this.customerId,
    required this.contactId,
    required this.jobId,
    required this.relatedInvoiceId,
    required this.creditDate,
    required this.totalAmount,
    required super.createdDate,
    required super.modifiedDate,
    this.creditNoteNum,
    this.externalCreditNoteId,
    this.status = CreditNoteStatus.draft,
    this.reason,
  }) : super();

  CreditNote.forInsert({
    required this.customerId,
    required this.contactId,
    required this.jobId,
    required this.relatedInvoiceId,
    required this.creditDate,
    required this.totalAmount,
    this.creditNoteNum,
    this.externalCreditNoteId,
    this.status = CreditNoteStatus.draft,
    this.reason,
  }) : super.forInsert();

  CreditNote copyWith({
    CreditNoteStatus? status,
    String? externalCreditNoteId,
  }) => CreditNote(
    id: id,
    customerId: customerId,
    contactId: contactId,
    jobId: jobId,
    relatedInvoiceId: relatedInvoiceId,
    creditNoteNum: creditNoteNum,
    externalCreditNoteId: externalCreditNoteId ?? this.externalCreditNoteId,
    creditDate: creditDate,
    totalAmount: totalAmount,
    status: status ?? this.status,
    reason: reason,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory CreditNote.fromMap(Map<String, dynamic> map) => CreditNote(
    id: map['id'] as int,
    customerId: map['customer_id'] as int?,
    contactId: map['contact_id'] as int?,
    jobId: map['job_id'] as int?,
    relatedInvoiceId: map['related_invoice_id'] as int?,
    creditNoteNum: map['credit_note_num'] as String?,
    externalCreditNoteId: map['external_credit_note_id'] as String?,
    creditDate: DateTime.parse(map['credit_date'] as String),
    totalAmount: Money.fromInt(map['total_amount'] as int, isoCode: 'AUD'),
    status: CreditNoteStatus.fromOrdinal(map['status'] as int?),
    reason: map['reason'] as String?,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'customer_id': customerId,
    'contact_id': contactId,
    'job_id': jobId,
    'related_invoice_id': relatedInvoiceId,
    'credit_note_num': creditNoteNum,
    'external_credit_note_id': externalCreditNoteId,
    'credit_date': creditDate.toIso8601String(),
    'total_amount': totalAmount.minorUnits.toInt(),
    'status': status.ordinal,
    'reason': reason,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

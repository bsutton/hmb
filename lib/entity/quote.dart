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

import 'entity.dart';

enum QuoteState {
  /// The quote is being reviewed internally.
  reviewing,

  /// Quote has been sent to the customer.
  sent,
  approved,
  rejected,

  /// The quote has been approved and we have
  ///  created at least one invoice from the quote.
  invoiced;

  bool get isPostApproval => this == approved || this == invoiced;
}

class Quote extends Entity<Quote> {
  int jobId;
  Money totalAmount;
  String assumption;
  String? quoteNum;
  String? externalQuoteId;
  QuoteState state;
  DateTime? dateSent;
  DateTime? dateApproved;
  int? billingContactId;

  Quote({
    required super.id,
    required this.jobId,
    required this.totalAmount,
    required this.assumption,
    required super.createdDate,
    required super.modifiedDate,
    required this.quoteNum,
    required this.state,
    this.externalQuoteId,
    this.dateSent,

    this.dateApproved,
    this.billingContactId,
  }) : super();

  Quote.forInsert({
    required this.jobId,
    required this.totalAmount,
    this.assumption = '',
    this.quoteNum,
    this.externalQuoteId,
    this.state = QuoteState.reviewing,
    this.dateSent,
    this.dateApproved,
    this.billingContactId,
  }) : super.forInsert();

  Quote.forUpdate({
    required super.entity,
    required this.jobId,
    required this.totalAmount,
    required this.assumption,
    required this.quoteNum,
    required this.state,
    this.externalQuoteId,
    this.dateSent,
    this.dateApproved,
    this.billingContactId,
  }) : super.forUpdate();

  factory Quote.fromMap(Map<String, dynamic> map) => Quote(
    id: map['id'] as int,
    jobId: map['job_id'] as int,
    totalAmount: Money.fromInt(map['total_amount'] as int, isoCode: 'AUD'),
    assumption: map['assumption'] as String,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
    quoteNum: map['quote_num'] as String?,
    externalQuoteId: map['external_quote_id'] as String?,
    state: QuoteState.values.byName(map['state'] as String),
    dateSent: map['date_sent'] != null
        ? DateTime.parse(map['date_sent'] as String)
        : null,
    dateApproved: map['date_approved'] != null
        ? DateTime.parse(map['date_approved'] as String)
        : null,
    billingContactId: map['billing_contact_id'] as int?,
  );

  String get bestNumber => externalQuoteId ?? quoteNum ?? '$id';

  Quote copyWith({
    int? id,
    int? jobId,
    String? assumption,
    Money? totalAmount,
    DateTime? createdDate,
    DateTime? modifiedDate,
    String? quoteNum,
    String? externalQuoteId,
    QuoteState? state,
    DateTime? dateSent,
    DateTime? dateApproved,
    int? billingContactId,
  }) => Quote(
    id: id ?? this.id,
    jobId: jobId ?? this.jobId,
    assumption: assumption ?? this.assumption,
    totalAmount: totalAmount ?? this.totalAmount,
    createdDate: createdDate ?? this.createdDate,
    modifiedDate: modifiedDate ?? this.modifiedDate,
    quoteNum: quoteNum ?? this.quoteNum,
    externalQuoteId: externalQuoteId ?? this.externalQuoteId,
    state: state ?? this.state,
    dateSent: dateSent ?? this.dateSent,
    dateApproved: dateApproved ?? this.dateApproved,
    billingContactId: billingContactId ?? this.billingContactId,
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'job_id': jobId,
    'total_amount': totalAmount.minorUnits.toInt(),
    'assumption': assumption,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
    'quote_num': quoteNum,
    'external_quote_id': externalQuoteId,
    'state': state.name,
    'date_sent': dateSent?.toIso8601String(),
    'date_approved': dateApproved?.toIso8601String(),
    'billing_contact_id': billingContactId,
  };
}

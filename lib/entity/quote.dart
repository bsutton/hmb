import 'package:money2/money2.dart';

import 'entity.dart';

enum QuoteState {
  reviewing,
  sent,
  approved,
  rejected;

  /// Creates a [QuoteState] from a string.
  static QuoteState fromString(String value) {
    switch (value) {
      case 'reviewing':
        return QuoteState.reviewing;
      case 'sent':
        return QuoteState.sent;
      case 'approved':
        return QuoteState.approved;
      case 'rejected':
        return QuoteState.rejected;
      default:
        throw ArgumentError('Invalid quote state: $value');
    }
  }
}

class Quote extends Entity<Quote> {
  Quote({
    required super.id,
    required this.jobId,
    required this.totalAmount,
    required super.createdDate,
    required super.modifiedDate,
    required this.quoteNum,
    required this.state,
    this.externalQuoteId,
    this.dateSent,
    this.dateApproved,
  }) : super();

  Quote.forInsert({
    required this.jobId,
    required this.totalAmount,
    this.quoteNum,
    this.externalQuoteId,
    this.state = QuoteState.reviewing,
    this.dateSent,
    this.dateApproved,
  }) : super.forInsert();

  Quote.forUpdate({
    required super.entity,
    required this.jobId,
    required this.totalAmount,
    required this.quoteNum,
    required this.state,
    this.externalQuoteId,
    this.dateSent,
    this.dateApproved,
  }) : super.forUpdate();

  factory Quote.fromMap(Map<String, dynamic> map) => Quote(
    id: map['id'] as int,
    jobId: map['job_id'] as int,
    totalAmount: Money.fromInt(map['total_amount'] as int, isoCode: 'AUD'),
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
    quoteNum: map['quote_num'] as String?,
    externalQuoteId: map['external_quote_id'] as String?,
    // Convert the stored string to a Dart enum
    state: QuoteState.fromString(map['state'] as String),
    dateSent:
        map['date_sent'] != null
            ? DateTime.parse(map['date_sent'] as String)
            : null,
    dateApproved:
        map['date_approved'] != null
            ? DateTime.parse(map['date_approved'] as String)
            : null,
  );

  int jobId;
  Money totalAmount;
  String? quoteNum;
  String? externalQuoteId;
  // New field as a Dart enum
  QuoteState state;
  DateTime? dateSent;
  DateTime? dateApproved;

  String get bestNumber => externalQuoteId ?? quoteNum ?? '$id';

  Quote copyWith({
    int? id,
    int? jobId,
    Money? totalAmount,
    DateTime? createdDate,
    DateTime? modifiedDate,
    String? quoteNum,
    String? externalQuoteId,
    QuoteState? state,
    DateTime? dateSent,
    DateTime? dateApproved,
  }) => Quote(
    id: id ?? this.id,
    jobId: jobId ?? this.jobId,
    totalAmount: totalAmount ?? this.totalAmount,
    createdDate: createdDate ?? this.createdDate,
    modifiedDate: modifiedDate ?? this.modifiedDate,
    quoteNum: quoteNum ?? this.quoteNum,
    externalQuoteId: externalQuoteId ?? this.externalQuoteId,
    state: state ?? this.state,
    dateSent: dateSent ?? this.dateSent,
    dateApproved: dateApproved ?? this.dateApproved,
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'job_id': jobId,
    'total_amount': totalAmount.minorUnits.toInt(),
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
    'quote_num': quoteNum,
    'external_quote_id': externalQuoteId,
    'state': state.name,
    'date_sent': dateSent?.toIso8601String(),
    'date_approved': dateApproved?.toIso8601String(),
  };
}

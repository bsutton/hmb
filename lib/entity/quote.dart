import 'package:money2/money2.dart';
import 'entity.dart';

class Quote extends Entity<Quote> {
  Quote({
    required super.id,
    required this.jobId,
    required this.totalAmount,
    required super.createdDate,
    required super.modifiedDate,
    required this.quoteNum,
    this.externalQuoteId,
  }) : super();

  Quote.forInsert({
    required this.jobId,
    required this.totalAmount,
  }) : super.forInsert();

  Quote.forUpdate({
    required super.entity,
    required this.jobId,
    required this.totalAmount,
    required this.quoteNum,
    this.externalQuoteId,
  }) : super.forUpdate();

  factory Quote.fromMap(Map<String, dynamic> map) => Quote(
        id: map['id'] as int,
        jobId: map['job_id'] as int,
        totalAmount: Money.fromInt(map['total_amount'] as int, isoCode: 'AUD'),
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
        quoteNum: map['quote_num'] as String?,
        externalQuoteId: map['external_quote_id'] as String?,
      );

  int jobId;
  Money totalAmount;
  String? quoteNum;
  String? externalQuoteId;

  String get bestNumber => externalQuoteId ?? quoteNum ?? '$id';

  Quote copyWith({
    int? id,
    int? jobId,
    Money? totalAmount,
    DateTime? createdDate,
    DateTime? modifiedDate,
    String? quoteNum,
    String? externalQuoteId,
  }) =>
      Quote(
        id: id ?? this.id,
        jobId: jobId ?? this.jobId,
        totalAmount: totalAmount ?? this.totalAmount,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate ?? this.modifiedDate,
        quoteNum: quoteNum ?? this.quoteNum,
        externalQuoteId: externalQuoteId ?? this.externalQuoteId,
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
      };
}

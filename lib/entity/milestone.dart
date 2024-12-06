import 'package:money2/money2.dart';

import '../entity/entity.dart';
import '../util/local_date.dart';
import '../util/money_ex.dart';

class Milestone extends Entity<Milestone> {
  Milestone({
    required super.id,
    required this.quoteId,
    required this.milestoneNumber,
    required this.status,
    required this.edited,
    required super.createdDate,
    required super.modifiedDate,
    this.invoiceId,
    this.paymentAmount,
    this.paymentPercentage,
    this.milestoneDescription,
    this.dueDate,
  }) : super();

  Milestone.forInsert({
    required this.quoteId,
    required this.milestoneNumber,
    this.invoiceId,
    this.paymentAmount,
    this.paymentPercentage,
    this.milestoneDescription,
    this.dueDate,
    this.status = 'pending',
    this.edited = false,
  }) : super.forInsert();

  factory Milestone.fromMap(Map<String, dynamic> map) => Milestone(
        id: map['id'] as int,
        quoteId: map['quote_id'] as int,
        invoiceId: map['invoice_id'] as int?,
        milestoneNumber: map['milestone_number'] as int,
        paymentAmount: map['payment_amount'] != null
            ? MoneyEx.fromInt(map['payment_amount'] as int)
            : null,
        paymentPercentage: map['payment_percentage'] != null
            ? Percentage.fromInt(map['payment_percentage'] as int)
            : null,
        milestoneDescription: map['milestone_description'] as String?,
        dueDate: map['due_date'] != null
            ? const LocalDateNullableConverter()
                .fromJson(map['due_date'] as String)
            : null,
        status: map['status'] as String,
        edited: (map['edited'] as int) == 1,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  int quoteId;
  int? invoiceId;
  int milestoneNumber;
  Money? paymentAmount;
  Percentage? paymentPercentage;
  String? milestoneDescription;
  LocalDate? dueDate;
  String status; // e.g., 'pending', 'invoiced', 'paid' - not currently used.
  bool edited; 

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'quote_id': quoteId,
        'invoice_id': invoiceId,
        'milestone_number': milestoneNumber,
        'payment_amount': paymentAmount?.twoDigits().minorUnits.toInt(),
        'payment_percentage': paymentPercentage?.copyWith(scale: 2).minorUnits.toInt(),
        'milestone_description': milestoneDescription,
        'due_date': const LocalDateNullableConverter().toJson(dueDate),
        'status': status,
        'edited': edited ? 1 : 0,
        'created_date': createdDate.toIso8601String(),
        'modified_date': modifiedDate.toIso8601String(),
      };

  Milestone copyWith({
    int? id,
    int? quoteId,
    int? invoiceId,
    int? milestoneNumber,
    Money? paymentAmount,
    Percentage? paymentPercentage,
    String? milestoneDescription,
    LocalDate? dueDate,
    String? status,
    bool? edited,
    DateTime? createdDate,
    DateTime? modifiedDate,
  }) =>
      Milestone(
        id: id ?? this.id,
        quoteId: quoteId ?? this.quoteId,
        invoiceId: invoiceId ?? this.invoiceId,
        milestoneNumber: milestoneNumber ?? this.milestoneNumber,
        paymentAmount: paymentAmount?.twoDigits() ?? this.paymentAmount,
        paymentPercentage: paymentPercentage?.copyWith(scale: 2) ?? this.paymentPercentage,
        milestoneDescription: milestoneDescription ?? this.milestoneDescription,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        edited: edited ?? this.edited,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate ?? this.modifiedDate,
      );
}

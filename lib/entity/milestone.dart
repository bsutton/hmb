import 'package:money2/money2.dart';

import '../entity/entity.dart';
import '../util/local_date.dart';
import '../util/money_ex.dart';

class Milestone extends Entity<Milestone> {
  Milestone({
    required super.id,
    required this.quoteId,
    required this.milestoneNumber,
    required this.dueDate,
    required super.createdDate,
    required super.modifiedDate,
    this.invoiceId,
    this.paymentPercentage,
    this.paymentAmount,
    this.milestoneDescription,
    this.status = 'pending',
  }) : super();

  Milestone.forInsert({
    required this.quoteId,
    required this.milestoneNumber,
    this.invoiceId,
    this.paymentPercentage,
    this.paymentAmount,
    this.milestoneDescription,
    this.dueDate,
    this.status = 'pending',
  }) : super.forInsert();

  factory Milestone.fromMap(Map<String, dynamic> map) => Milestone(
        id: map['id'] as int,
        quoteId: map['quote_id'] as int,
        invoiceId: map['invoice_id'] as int?,
        milestoneNumber: map['milestone_number'] as int,
        paymentPercentage: Percentage.fromInt(map['payment_percentage'] as int),
        paymentAmount: map['payment_amount'] != null
            ? MoneyEx.fromInt(map['payment_amount'] as int)
            : null,
        milestoneDescription: map['milestone_description'] as String?,
        dueDate: map['due_date'] != null
            ? const LocalDateNullableConverter()
                .fromJson(map['due_date'] as String)
            : null,
        status: map['status'] as String,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  int quoteId;
  int? invoiceId;
  int milestoneNumber;
  Percentage? paymentPercentage;
  Money? paymentAmount;
  String? milestoneDescription;
  LocalDate? dueDate;
  String status; // e.g., 'pending', 'invoiced', 'paid'

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'quote_id': quoteId,
        'invoice_id': invoiceId,
        'milestone_number': milestoneNumber,
        'payment_percentage': paymentPercentage?.minorUnits.toInt(),
        'payment_amount': paymentAmount?.twoDigits().minorUnits.toInt(),
        'milestone_description': milestoneDescription,
        'due_date': const LocalDateNullableConverter().toJson(dueDate),
        'status': status,
        'created_date': createdDate.toIso8601String(),
        'modified_date': modifiedDate.toIso8601String(),
      };

  Milestone copyWith({
    int? id,
    int? quoteId,
    int? invoiceId,
    int? milestoneNumber,
    Percentage? paymentPercentage,
    Money? paymentAmount,
    String? milestoneDescription,
    LocalDate? dueDate,
    String? status,
    DateTime? createdDate,
    DateTime? modifiedDate,
  }) =>
      Milestone(
        id: id ?? this.id,
        quoteId: quoteId ?? this.quoteId,
        invoiceId: invoiceId ?? this.invoiceId,
        milestoneNumber: milestoneNumber ?? this.milestoneNumber,
        paymentPercentage: paymentPercentage ?? this.paymentPercentage,
        paymentAmount: paymentAmount ?? this.paymentAmount,
        milestoneDescription: milestoneDescription ?? this.milestoneDescription,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate ?? this.modifiedDate,
      );
}

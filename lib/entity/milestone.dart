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

import '../entity/entity.dart';
import '../util/dart/local_date.dart';
import '../util/dart/money_ex.dart';

class Milestone extends Entity<Milestone> {
  int quoteId;
  int? invoiceId;
  int milestoneNumber;
  Money paymentAmount;
  Percentage paymentPercentage;
  String? milestoneDescription;
  LocalDate? dueDate;
  bool edited;

  Milestone({
    required super.id,
    required this.quoteId,
    required this.milestoneNumber,
    required this.edited,
    required this.paymentAmount,
    required this.paymentPercentage,
    required super.createdDate,
    required super.modifiedDate,
    this.invoiceId,
    this.milestoneDescription,
    this.dueDate,
  }) : super();

  Milestone.forInsert({
    required this.quoteId,
    required this.milestoneNumber,
    required this.paymentAmount,
    required this.paymentPercentage,
    this.invoiceId,
    this.milestoneDescription,
    this.dueDate,
    this.edited = false,
  }) : super.forInsert();

  Milestone copyWith({
    int? id,
    int? quoteId,
    int? invoiceId,
    int? milestoneNumber,
    Money? paymentAmount,
    Percentage? paymentPercentage,
    String? milestoneDescription,
    LocalDate? dueDate,
    bool? edited,
    DateTime? createdDate,
    DateTime? modifiedDate,
  }) => Milestone(
    id: id ?? this.id,
    quoteId: quoteId ?? this.quoteId,
    invoiceId: invoiceId ?? this.invoiceId,
    milestoneNumber: milestoneNumber ?? this.milestoneNumber,
    paymentAmount: paymentAmount?.twoDigits() ?? this.paymentAmount,
    paymentPercentage:
        paymentPercentage?.copyWith(decimalDigits: 2) ?? this.paymentPercentage,
    milestoneDescription: milestoneDescription ?? this.milestoneDescription,
    dueDate: dueDate ?? this.dueDate,
    edited: edited ?? this.edited,
    createdDate: createdDate ?? this.createdDate,
    modifiedDate: modifiedDate ?? this.modifiedDate,
  );

  factory Milestone.fromMap(Map<String, dynamic> map) => Milestone(
    id: map['id'] as int,
    quoteId: map['quote_id'] as int,
    invoiceId: map['invoice_id'] as int?,
    milestoneNumber: map['milestone_number'] as int,
    paymentAmount: MoneyEx.fromInt(map['payment_amount'] as int),
    paymentPercentage: Percentage.fromInt(map['payment_percentage'] as int),
    milestoneDescription: map['milestone_description'] as String?,
    dueDate: map['due_date'] != null
        ? const LocalDateNullableConverter().fromJson(map['due_date'] as String)
        : null,

    edited: (map['edited'] as int) == 1,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'quote_id': quoteId,
    'invoice_id': invoiceId,
    'milestone_number': milestoneNumber,
    'payment_amount': paymentAmount.twoDigits().minorUnits.toInt(),
    'payment_percentage': paymentPercentage
        .copyWith(decimalDigits: 2)
        .minorUnits
        .toInt(),
    'milestone_description': milestoneDescription,
    'due_date': const LocalDateNullableConverter().toJson(dueDate),
    'edited': edited ? 1 : 0,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };

  int get hash => Object.hash(
    id,
    quoteId,
    milestoneNumber,
    edited,
    createdDate,
    modifiedDate,
    invoiceId,
    paymentAmount,
    paymentPercentage,
    milestoneDescription,
    dueDate,
  );
}

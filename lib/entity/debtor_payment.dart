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

class DebtorPayment extends Entity<DebtorPayment> {
  int? customerId;
  int? contactId;
  DateTime paymentDate;
  Money amount;
  String? paymentMethod;
  String? reference;
  String? notes;
  String? externalPaymentId;
  String? externalProvider;

  DebtorPayment({
    required super.id,
    required this.customerId,
    required this.contactId,
    required this.paymentDate,
    required this.amount,
    required super.createdDate,
    required super.modifiedDate,
    this.paymentMethod,
    this.reference,
    this.notes,
    this.externalPaymentId,
    this.externalProvider,
  }) : super();

  DebtorPayment.forInsert({
    required this.customerId,
    required this.contactId,
    required this.paymentDate,
    required this.amount,
    this.paymentMethod,
    this.reference,
    this.notes,
    this.externalPaymentId,
    this.externalProvider,
  }) : super.forInsert();

  factory DebtorPayment.fromMap(Map<String, dynamic> map) => DebtorPayment(
    id: map['id'] as int,
    customerId: map['customer_id'] as int?,
    contactId: map['contact_id'] as int?,
    paymentDate: DateTime.parse(map['payment_date'] as String),
    amount: Money.fromInt(map['amount'] as int, isoCode: 'AUD'),
    paymentMethod: map['payment_method'] as String?,
    reference: map['reference'] as String?,
    notes: map['notes'] as String?,
    externalPaymentId: map['external_payment_id'] as String?,
    externalProvider: map['external_provider'] as String?,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'customer_id': customerId,
    'contact_id': contactId,
    'payment_date': paymentDate.toIso8601String(),
    'amount': amount.minorUnits.toInt(),
    'payment_method': paymentMethod,
    'reference': reference,
    'notes': notes,
    'external_payment_id': externalPaymentId,
    'external_provider': externalProvider,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

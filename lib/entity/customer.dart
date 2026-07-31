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

import '../util/dart/money_ex.dart';
import 'entity.dart';

enum CustomerType {
  residential('Residential'),
  commercial('Commercial'),
  tradePartner('Trade Partner'),
  community('Community');

  const CustomerType(this.display);
  final String display;
}

class Customer extends Entity<Customer> {
  final String name;
  final String? description;
  final bool disbarred;
  final bool excludeFromMailings;
  final CustomerType customerType;
  final Money hourlyRate;
  final int? billingContactId;

  Customer({
    required super.id,
    required this.name,
    required this.description,
    required this.disbarred,
    required this.customerType,
    required this.hourlyRate,
    required this.billingContactId,
    required super.createdDate,
    required super.modifiedDate,
    this.excludeFromMailings = false,
  }) : super();

  Customer.forInsert({
    required this.name,
    required this.description,
    required this.disbarred,
    required this.customerType,
    required this.hourlyRate,
    required this.billingContactId,
    this.excludeFromMailings = false,
  }) : super.forInsert();

  Customer copyWith({
    String? name,
    String? description,
    bool? disbarred,
    bool? excludeFromMailings,
    CustomerType? customerType,
    Money? hourlyRate,
    int? billingContactId,
  }) => Customer(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    disbarred: disbarred ?? this.disbarred,
    excludeFromMailings: excludeFromMailings ?? this.excludeFromMailings,
    customerType: customerType ?? this.customerType,
    hourlyRate: hourlyRate ?? this.hourlyRate,
    billingContactId: billingContactId ?? this.billingContactId,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    id: map['id'] as int,
    name: map['name'] as String,
    description: map['description'] as String?,
    disbarred: map['disbarred'] as int == 1,
    excludeFromMailings: (map['exclude_from_mailings'] as int? ?? 0) == 1,
    customerType: CustomerType.values[map['customerType'] as int],
    hourlyRate: MoneyEx.fromInt(map['default_hourly_rate'] as int?),
    billingContactId: map['billing_contact_id'] as int?,
    createdDate: DateTime.parse(map['createdDate'] as String),
    modifiedDate: DateTime.parse(map['modifiedDate'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
    'disbarred': disbarred ? 1 : 0,
    'exclude_from_mailings': excludeFromMailings ? 1 : 0,
    'customerType': customerType.index,
    'default_hourly_rate': hourlyRate.minorUnits.toInt(),
    'billing_contact_id': billingContactId,
  };
}

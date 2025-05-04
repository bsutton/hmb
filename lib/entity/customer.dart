import 'package:money2/money2.dart';

import '../util/money_ex.dart';
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
  }) : super();

  Customer.forInsert({
    required this.name,
    required this.description,
    required this.disbarred,
    required this.customerType,
    required this.hourlyRate,
    required this.billingContactId,
  }) : super.forInsert();

  Customer.forUpdate({
    required super.entity,
    required this.name,
    required this.description,
    required this.disbarred,
    required this.customerType,
    required this.hourlyRate,
    required this.billingContactId,
  }) : super.forUpdate();

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    id: map['id'] as int,
    name: map['name'] as String,
    description: map['description'] as String?,
    createdDate: DateTime.parse(map['createdDate'] as String),
    modifiedDate: DateTime.parse(map['modifiedDate'] as String),
    disbarred: map['disbarred'] as int == 1,
    customerType: CustomerType.values[map['customerType'] as int],
    hourlyRate: MoneyEx.fromInt(map['default_hourly_rate'] as int?),
    billingContactId: map['billing_contact_id'] as int?,
  );
  final String name;
  final String? description;
  final bool disbarred;
  final CustomerType customerType;
  final Money hourlyRate;
  final int? billingContactId;

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
    'disbarred': disbarred ? 1 : 0,
    'customerType': customerType.index,
    'default_hourly_rate': hourlyRate.minorUnits.toInt(),
    'billing_contact_id': billingContactId,
  };
}

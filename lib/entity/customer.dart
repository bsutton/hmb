import 'package:money2/money2.dart';

import '../util/money_ex.dart';
import 'entity.dart';

enum CustomerType { residential, realestate, tradePartner, community }

class Customer extends Entity<Customer> {
  Customer({
    required super.id,
    required this.name,
    required this.description,
    required this.disbarred,
    required this.customerType,
    required this.hourlyRate,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  Customer.forInsert({
    required this.name,
    required this.description,
    required this.disbarred,
    required this.customerType,
    required this.hourlyRate,
  }) : super.forInsert();

  Customer.forUpdate({
    required super.entity,
    required this.name,
    required this.description,
    required this.disbarred,
    required this.customerType,
    required this.hourlyRate,
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
      );

  String name;
  String? description;
  bool disbarred;
  CustomerType customerType;
  Money hourlyRate;

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
      };
}

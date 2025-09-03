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

import 'entity.dart';

enum SupplierType { residential, realestate, tradePartner, community }

class Supplier extends Entity<Supplier> {
  String name;
  String? businessNumber;
  String? description;
  String? bsb;
  String? accountNumber;
  String? service;

  Supplier({
    required super.id,
    required this.name,
    required this.businessNumber,
    required this.description,
    required this.bsb,
    required this.accountNumber,
    required this.service,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  Supplier.forInsert({
    required this.name,
    required this.businessNumber,
    required this.description,
    required this.bsb,
    required this.accountNumber,
    required this.service,
  }) : super.forInsert();

  Supplier copyWith({
    String? name,
    String? businessNumber,
    String? description,
    String? bsb,
    String? accountNumber,
    String? service,
  }) => Supplier(
    id: id,
    name: name ?? this.name,
    businessNumber: businessNumber ?? this.businessNumber,
    description: description ?? this.description,
    bsb: bsb ?? this.bsb,
    accountNumber: accountNumber ?? this.accountNumber,
    service: service ?? this.service,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
    id: map['id'] as int,
    name: map['name'] as String,
    businessNumber: map['businessNumber'] as String?,
    description: map['description'] as String?,
    bsb: map['bsb'] as String?,
    accountNumber: map['accountNumber'] as String?,
    service: map['service'] as String?,
    createdDate: DateTime.parse(map['createdDate'] as String),
    modifiedDate: DateTime.parse(map['modifiedDate'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'businessNumber': businessNumber,
    'description': description,
    'bsb': bsb,
    'accountNumber': accountNumber,
    'service': service,
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
  };
}

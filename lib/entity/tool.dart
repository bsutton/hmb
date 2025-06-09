import 'package:money2/money2.dart';

import '../util/money_ex.dart';
import 'entity.dart';

class Tool extends Entity<Tool> {
  Tool({
    required super.id,
    required this.name,
    required super.createdDate,
    required super.modifiedDate,
    this.categoryId,
    this.supplierId,
    this.manufacturerId,
    this.datePurchased,
    this.serialNumber,
    this.receiptPhotoId,
    this.serialNumberPhotoId,
    this.warrantyPeriod,
    this.cost,
    this.description,
  });

  Tool.forInsert({
    required this.name,
    this.categoryId,
    this.supplierId,
    this.manufacturerId,
    this.datePurchased,
    this.serialNumber,
    this.receiptPhotoId,
    this.serialNumberPhotoId,
    this.warrantyPeriod,
    this.cost,
    this.description,
  }) : super.forInsert();

  Tool.forUpdate({
    required Tool entity,
    required this.name,
    this.categoryId,
    this.supplierId,
    this.manufacturerId,
    this.datePurchased,
    this.serialNumber,
    this.receiptPhotoId,
    this.serialNumberPhotoId,
    this.warrantyPeriod,
    this.cost,
    this.description,
  }) : super.forUpdate(entity: entity);

  factory Tool.fromMap(Map<String, dynamic> map) => Tool(
    id: map['id'] as int,
    name: map['name'] as String,
    categoryId: map['categoryId'] as int?,
    supplierId: map['supplierId'] as int?,
    manufacturerId: map['manufacturerId'] as int?,
    datePurchased: map['datePurchased'] != null
        ? DateTime.parse(map['datePurchased'] as String)
        : null,
    serialNumber: map['serialNumber'] as String?,
    receiptPhotoId: map['receiptPhotoId'] as int?,
    serialNumberPhotoId: map['serialNumberPhotoId'] as int?,
    warrantyPeriod: map['warrantyPeriod'] as int?,
    cost: _moneyOrNull(map['cost'] as int?),
    description: map['description'] as String?,
    createdDate: DateTime.parse(map['createdDate'] as String),
    modifiedDate: DateTime.parse(map['modifiedDate'] as String),
  );

  final String name;
  final int? categoryId;
  final int? supplierId;
  final int? manufacturerId;
  final DateTime? datePurchased;
  final String? serialNumber;
  final int? receiptPhotoId;
  final int? serialNumberPhotoId;
  final int? warrantyPeriod;
  final Money? cost;
  final String? description;

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'categoryId': categoryId,
    'supplierId': supplierId,
    'manufacturerId': manufacturerId,
    'datePurchased': datePurchased?.toIso8601String(),
    'serialNumber': serialNumber,
    'receiptPhotoId': receiptPhotoId,
    'serialNumberPhotoId': serialNumberPhotoId,
    'warrantyPeriod': warrantyPeriod,
    'cost': cost?.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'description': description,
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
  };

  Tool copyWith({
    int? id,
    String? name,
    DateTime? createdDate,
    DateTime? modifiedDate,
    int? categoryId,
    int? supplierId,
    int? manufacturerId,
    DateTime? datePurchased,
    String? serialNumber,
    int? receiptPhotoId,
    int? serialNumberPhotoId,
    int? warrantyPeriod,
    Money? cost,
    String? description,
  }) => Tool(
    id: id ?? this.id,
    name: name ?? this.name,
    createdDate: createdDate ?? this.createdDate,
    modifiedDate: modifiedDate ?? this.modifiedDate,
    categoryId: categoryId ?? this.categoryId,
    supplierId: supplierId ?? this.supplierId,
    manufacturerId: manufacturerId ?? this.manufacturerId,
    datePurchased: datePurchased ?? this.datePurchased,
    serialNumber: serialNumber ?? this.serialNumber,
    receiptPhotoId: receiptPhotoId ?? this.receiptPhotoId,
    serialNumberPhotoId: serialNumberPhotoId ?? this.serialNumberPhotoId,
    warrantyPeriod: warrantyPeriod ?? this.warrantyPeriod,
    cost: cost ?? this.cost,
    description: description ?? this.description,
  );
}

Money? _moneyOrNull(int? amount) {
  if (amount == null) {
    return null;
  }
  return MoneyEx.fromInt(amount);
}

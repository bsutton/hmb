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
    this.receiptPhotoPath,
    this.serialNumberPhotoPath,
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
    this.receiptPhotoPath,
    this.serialNumberPhotoPath,
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
    this.receiptPhotoPath,
    this.serialNumberPhotoPath,
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
        receiptPhotoPath: map['receiptPhotoPath'] as String?,
        serialNumberPhotoPath: map['serialNumberPhotoPath'] as String?,
        warrantyPeriod: map['warrantyPeriod'] as int?,
        cost: _moneyOrNull(map['cost'] as int?),
        description: map['description'] as String?,
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
      );

  final String name;
  final int? categoryId; // Foreign key reference to Category
  final int? supplierId;
  final int? manufacturerId;
  final DateTime? datePurchased;
  final String? serialNumber;
  final String? receiptPhotoPath;
  final String? serialNumberPhotoPath;
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
        'receiptPhotoPath': receiptPhotoPath,
        'serialNumberPhotoPath': serialNumberPhotoPath,
        'warrantyPeriod': warrantyPeriod,
        'cost': cost?.copyWith(decimalDigits: 2).minorUnits.toInt(),
        'description': description,
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate.toIso8601String(),
      };
}

Money? _moneyOrNull(int? amount) {
  if (amount == null) {
    return null;
  }
  return MoneyEx.fromInt(amount);
}

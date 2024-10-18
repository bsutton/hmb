import 'entity.dart';

class Tool extends Entity<Tool> {
  Tool({
    required super.id,
    required this.name,
    required this.category,
    required this.supplierId,
    required super.createdDate,
    required super.modifiedDate,
    this.datePurchased,
    this.serialNumber,
  });
  final String name;
  final String category;
  final DateTime? datePurchased;
  final String? serialNumber;
  final int supplierId;

  // Map conversion methods
  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'datePurchased': datePurchased?.toIso8601String(),
        'serialNumber': serialNumber,
        'supplierId': supplierId,
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate.toIso8601String(),
      };

  static Tool fromMap(Map<String, dynamic> map) => Tool(
        id: map['id'] as int,
        name: map['name'] as String,
        category: map['category'] as String,
        datePurchased: map['datePurchased'] != null
            ? DateTime.parse(map['datePurchased'] as String)
            : null,
        serialNumber: map['serialNumber'] as String?,
        supplierId: map['supplierId'] as int,
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
      );
}

import 'entity.dart';

class Manufacturer extends Entity<Manufacturer> {
  Manufacturer({
    required super.id,
    required this.name,
    required super.createdDate,
    required super.modifiedDate,
    this.description,
    this.contactNumber,
    this.email,
    this.address,
  });

  Manufacturer.forInsert({
    required this.name,
    this.description,
    this.contactNumber,
    this.email,
    this.address,
  }) : super.forInsert();

  Manufacturer.forUpdate({
    required super.entity,
    required this.name,
    this.description,
    this.contactNumber,
    this.email,
    this.address,
  }) : super.forUpdate();

  factory Manufacturer.fromMap(Map<String, dynamic> map) => Manufacturer(
        id: map['id'] as int,
        name: map['name'] as String,
        description: map['description'] as String?,
        contactNumber: map['contactNumber'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
      );

  String name;
  String? description;
  String? contactNumber;
  String? email;
  String? address;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'contactNumber': contactNumber,
        'email': email,
        'address': address,
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate.toIso8601String(),
      };
}

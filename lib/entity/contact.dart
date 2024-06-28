import 'entity.dart';

class Contact extends Entity<Contact> {
  Contact({
    required super.id,
    required this.firstName,
    required this.surname,
    required this.mobileNumber,
    required this.landLine,
    required this.officeNumber,
    required this.emailAddress,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  Contact.forInsert({
    required this.firstName,
    required this.surname,
    required this.mobileNumber,
    required this.landLine,
    required this.officeNumber,
    required this.emailAddress,
  }) : super.forInsert();

  Contact.forUpdate({
    required super.entity,
    required this.firstName,
    required this.surname,
    required this.mobileNumber,
    required this.landLine,
    required this.officeNumber,
    required this.emailAddress,
  }) : super.forUpdate();

  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
        id: map['id'] as int,
        firstName: map['firstName'] as String,
        surname: map['surname'] as String,
        mobileNumber: map['mobileNumber'] as String,
        landLine: map['landLine'] as String,
        officeNumber: map['officeNumber'] as String,
        emailAddress: map['emailAddress'] as String,
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
      );
  String firstName;
  String surname;
  String mobileNumber;
  String landLine;
  String officeNumber;
  String emailAddress;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'firstName': firstName,
        'surname': surname,
        'mobileNumber': mobileNumber,
        'landLine': landLine,
        'officeNumber': officeNumber,
        'emailAddress': emailAddress,
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate.toIso8601String(),
      };

  String abbreviated() => '$firstName $surname';
}

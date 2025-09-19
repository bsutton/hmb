/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:strings/strings.dart';

import '../api/xero/models/xero_contact.dart';
import 'entity.dart';

class Contact extends Entity<Contact> {
  String firstName;
  String surname;
  String mobileNumber;
  String landLine;
  String officeNumber;
  String emailAddress; // primary (non-null)
  String? alternateEmail;
  String? xeroContactId;

  Contact._({
    required super.id,
    required this.firstName,
    required this.surname,
    required this.mobileNumber,
    required this.landLine,
    required this.officeNumber,
    required this.emailAddress,
    required super.createdDate,
    required super.modifiedDate,
    this.alternateEmail,
    this.xeroContactId,
  }) : super();

  Contact.forInsert({
    required this.firstName,
    required this.surname,
    required this.mobileNumber,
    required this.landLine,
    required this.officeNumber,
    required this.emailAddress,
    this.xeroContactId,
    this.alternateEmail,
  }) : super.forInsert();

  Contact copyWith({
    String? firstName,
    String? surname,
    String? mobileNumber,
    String? landLine,
    String? officeNumber,
    String? emailAddress,
    String? xeroContactId,
    String? alternateEmail,
  }) => Contact._(
    id: id,
    firstName: firstName ?? this.firstName,
    surname: surname ?? this.surname,
    mobileNumber: mobileNumber ?? this.mobileNumber,
    landLine: landLine ?? this.landLine,
    officeNumber: officeNumber ?? this.officeNumber,
    emailAddress: emailAddress ?? this.emailAddress,
    alternateEmail: alternateEmail ?? this.alternateEmail,
    xeroContactId: xeroContactId ?? this.xeroContactId,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory Contact.fromMap(Map<String, dynamic> map) => Contact._(
    id: map['id'] as int,
    firstName: map['firstName'] as String,
    surname: map['surname'] as String,
    mobileNumber: map['mobileNumber'] as String,
    landLine: map['landLine'] as String,
    officeNumber: map['officeNumber'] as String,
    emailAddress: map['emailAddress'] as String,
    alternateEmail: map['alternateEmail'] as String?, // NEW
    xeroContactId: map['xeroContactId'] as String?,
    createdDate: DateTime.parse(map['createdDate'] as String),
    modifiedDate: DateTime.parse(map['modifiedDate'] as String),
  );

  String get fullname => '$firstName $surname';

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'firstName': firstName,
    'surname': surname,
    'mobileNumber': mobileNumber,
    'landLine': landLine,
    'officeNumber': officeNumber,
    'emailAddress': emailAddress,
    'alternateEmail': alternateEmail, // NEW
    'xeroContactId': xeroContactId,
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
  };

  String abbreviated() => '$firstName $surname';

  // Optional helper: prefer primary, otherwise fall back to alternate
  String get bestEmail =>
      Strings.isNotBlank(emailAddress) ? emailAddress : (alternateEmail ?? '');

  XeroContact toXeroContact() =>
      XeroContact(name: fullname, email: bestEmail, phone: bestPhone);

  String get bestPhone {
    if (Strings.isNotBlank(mobileNumber)) {
      return mobileNumber;
    } else if (Strings.isNotBlank(officeNumber)) {
      return officeNumber;
    } else if (Strings.isNotBlank(landLine)) {
      return landLine;
    } else {
      return '';
    }
  }
}

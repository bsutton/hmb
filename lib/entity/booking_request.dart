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

enum BookingRequestStatus {
  pending(0),
  imported(1),
  rejected(2);

  final int ordinal;
  const BookingRequestStatus(this.ordinal);

  static BookingRequestStatus fromOrdinal(int? value) =>
      value == BookingRequestStatus.imported.ordinal
      ? BookingRequestStatus.imported
      : value == BookingRequestStatus.rejected.ordinal
      ? BookingRequestStatus.rejected
      : BookingRequestStatus.pending;
}

class BookingRequest extends Entity<BookingRequest> {
  String remoteId;
  BookingRequestStatus status;
  String name;
  String businessName;
  String firstName;
  String surname;
  String email;
  String phone;
  String description;
  String street;
  String suburb;
  String day1;
  String day2;
  String day3;

  BookingRequest._({
    required super.id,
    required this.remoteId,
    required this.status,
    required this.name,
    required this.businessName,
    required this.firstName,
    required this.surname,
    required this.email,
    required this.phone,
    required this.description,
    required this.street,
    required this.suburb,
    required this.day1,
    required this.day2,
    required this.day3,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  BookingRequest.forInsert({
    required this.remoteId,
    required this.status,
    required this.name,
    required this.businessName,
    required this.firstName,
    required this.surname,
    required this.email,
    required this.phone,
    required this.description,
    required this.street,
    required this.suburb,
    required this.day1,
    required this.day2,
    required this.day3,
  }) : super.forInsert();

  BookingRequest copyWith({
    BookingRequestStatus? status,
    String? name,
    String? businessName,
    String? firstName,
    String? surname,
    String? email,
    String? phone,
    String? description,
    String? street,
    String? suburb,
    String? day1,
    String? day2,
    String? day3,
  }) =>
      BookingRequest._(
        id: id,
        remoteId: remoteId,
        status: status ?? this.status,
        name: name ?? this.name,
        businessName: businessName ?? this.businessName,
        firstName: firstName ?? this.firstName,
        surname: surname ?? this.surname,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        description: description ?? this.description,
        street: street ?? this.street,
        suburb: suburb ?? this.suburb,
        day1: day1 ?? this.day1,
        day2: day2 ?? this.day2,
        day3: day3 ?? this.day3,
        createdDate: createdDate,
        modifiedDate: DateTime.now(),
      );

  factory BookingRequest.fromMap(Map<String, dynamic> map) => BookingRequest._(
    id: map['id'] as int,
    remoteId: map['remote_id'] as String,
    status: BookingRequestStatus.fromOrdinal(map['status'] as int?),
    name: (map['name'] as String?) ?? '',
    businessName: (map['business_name'] as String?) ?? '',
    firstName: (map['first_name'] as String?) ?? '',
    surname: (map['surname'] as String?) ?? '',
    email: (map['email'] as String?) ?? '',
    phone: (map['phone'] as String?) ?? '',
    description: (map['description'] as String?) ?? '',
    street: (map['street'] as String?) ?? '',
    suburb: (map['suburb'] as String?) ?? '',
    day1: (map['day1'] as String?) ?? '',
    day2: (map['day2'] as String?) ?? '',
    day3: (map['day3'] as String?) ?? '',
    createdDate: DateTime.parse(map['createdDate'] as String),
    modifiedDate: DateTime.parse(map['modifiedDate'] as String),
  );

  BookingRequestPayload get parsedPayload => BookingRequestPayload(
    name: name.trim(),
    businessName: businessName.trim(),
    firstName: firstName.trim(),
    surname: surname.trim(),
    email: email.trim(),
    phone: phone.trim(),
    description: description.trim(),
    street: street.trim(),
    suburb: suburb.trim(),
    day1: day1.trim(),
    day2: day2.trim(),
    day3: day3.trim(),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'remote_id': remoteId,
    'status': status.ordinal,
    'name': name,
    'business_name': businessName,
    'first_name': firstName,
    'surname': surname,
    'email': email,
    'phone': phone,
    'description': description,
    'street': street,
    'suburb': suburb,
    'day1': day1,
    'day2': day2,
    'day3': day3,
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
  };
}

class BookingRequestPayload {
  final String name;
  final String businessName;
  final String firstName;
  final String surname;
  final String email;
  final String phone;
  final String description;
  final String street;
  final String suburb;
  final String day1;
  final String day2;
  final String day3;

  BookingRequestPayload({
    required this.name,
    required this.businessName,
    required this.firstName,
    required this.surname,
    required this.email,
    required this.phone,
    required this.description,
    required this.street,
    required this.suburb,
    required this.day1,
    required this.day2,
    required this.day3,
  });

  factory BookingRequestPayload.fromMap(Map<String, dynamic> map) =>
      BookingRequestPayload(
        name: (map['name'] as String?)?.trim() ?? '',
        businessName: (map['business_name'] as String?)?.trim() ?? '',
        firstName: (map['first_name'] as String?)?.trim() ?? '',
        surname: (map['surname'] as String?)?.trim() ?? '',
        email: (map['email'] as String?)?.trim() ?? '',
        phone: (map['phone'] as String?)?.trim() ?? '',
        description: (map['description'] as String?)?.trim() ?? '',
        street: (map['street'] as String?)?.trim() ?? '',
        suburb: (map['suburb'] as String?)?.trim() ?? '',
        day1: (map['day1'] as String?)?.trim() ?? '',
        day2: (map['day2'] as String?)?.trim() ?? '',
        day3: (map['day3'] as String?)?.trim() ?? '',
      );
}

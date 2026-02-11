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

import 'dart:convert';

import 'package:booking_request/booking_request.dart' as br;

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
  String payload;

  BookingRequest._({
    required super.id,
    required this.remoteId,
    required this.status,
    required this.payload,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  BookingRequest.forInsert({
    required this.remoteId,
    required this.status,
    required this.payload,
  }) : super.forInsert();

  BookingRequest copyWith({BookingRequestStatus? status, String? payload}) =>
      BookingRequest._(
        id: id,
        remoteId: remoteId,
        status: status ?? this.status,
        payload: payload ?? this.payload,
        createdDate: createdDate,
        modifiedDate: DateTime.now(),
      );

  factory BookingRequest.fromMap(Map<String, dynamic> map) => BookingRequest._(
    id: map['id'] as int,
    remoteId: map['remote_id'] as String,
    status: BookingRequestStatus.fromOrdinal(map['status'] as int?),
    payload: map['payload'] as String,
    createdDate: DateTime.parse(map['createdDate'] as String),
    modifiedDate: DateTime.parse(map['modifiedDate'] as String),
  );

  Map<String, dynamic> get payloadMap =>
      jsonDecode(payload) as Map<String, dynamic>;

  BookingRequestPayload get parsedPayload {
    try {
      final parsed = br.BookingRequest.fromJson(payloadMap);
      return BookingRequestPayload(
        name: _buildName(parsed),
        businessName: parsed.businessName.trim(),
        firstName: parsed.firstName.trim(),
        surname: parsed.surname.trim(),
        email: parsed.email.trim(),
        phone: parsed.phone.trim(),
        description: parsed.description.trim(),
        street: parsed.street.trim(),
        suburb: parsed.suburb.trim(),
        day1: parsed.day1.trim(),
        day2: parsed.day2.trim(),
        day3: parsed.day3.trim(),
      );
    } catch (_) {
      return BookingRequestPayload.fromMap(payloadMap);
    }
  }

  static String _buildName(br.BookingRequest parsed) {
    final fullName = '${parsed.firstName} ${parsed.surname}'.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }
    if (parsed.businessName.trim().isNotEmpty) {
      return parsed.businessName.trim();
    }
    return '';
  }

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'remote_id': remoteId,
    'status': status.ordinal,
    'payload': payload,
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
      BookingRequestPayload._fromPayloadMap(map);

  factory BookingRequestPayload._fromPayloadMap(Map<String, dynamic> map) {
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;
    final businessName = (data['businessName'] as String?)?.trim() ?? '';
    final firstName = (data['firstName'] as String?)?.trim() ?? '';
    final surname = (data['surname'] as String?)?.trim() ?? '';
    final directName = (data['name'] as String?)?.trim() ?? '';
    final fullName = '$firstName $surname'.trim();
    final derivedName = directName.isNotEmpty
        ? directName
        : (fullName.isNotEmpty ? fullName : businessName);

    return BookingRequestPayload(
      name: derivedName,
      businessName: businessName,
      firstName: firstName,
      surname: surname,
      email: (data['email'] as String?)?.trim() ?? '',
      phone: (data['phone'] as String?)?.trim() ?? '',
      description: (data['description'] as String?)?.trim() ?? '',
      street: (data['street'] as String?)?.trim() ?? '',
      suburb: (data['suburb'] as String?)?.trim() ?? '',
      day1: (data['day1'] as String?)?.trim() ?? '',
      day2: (data['day2'] as String?)?.trim() ?? '',
      day3: (data['day3'] as String?)?.trim() ?? '',
    );
  }
}

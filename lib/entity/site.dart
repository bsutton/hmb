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

import 'package:strings/strings.dart';

import '../util/dart/address_format.dart';
import 'entity.dart';

class Site extends Entity<Site> {
  String? name;
  String addressLine1;
  String addressLine2;
  String suburb;
  String state;
  String postcode;
  double? latitude;
  double? longitude;
  String? geocodeStatus;
  DateTime? geocodedAt;

  /// Hold info such as pin codes for lock boxes.
  String? accessDetails;

  Site._({
    required super.id,
    required this.name,
    required this.addressLine1,
    required this.addressLine2,
    required this.suburb,
    required this.state,
    required this.postcode,
    required this.accessDetails,
    required this.latitude,
    required this.longitude,
    required this.geocodeStatus,
    required this.geocodedAt,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  Site.forInsert({
    required this.addressLine1,
    required this.addressLine2,
    required this.suburb,
    required this.state,
    required this.postcode,
    required this.accessDetails,
    this.name,
    this.latitude,
    this.longitude,
    this.geocodeStatus,
    this.geocodedAt,
  }) : super.forInsert();

  Site copyWith({
    String? name,
    String? addressLine1,
    String? addressLine2,
    String? suburb,
    String? state,
    String? postcode,
    String? accessDetails,
    double? latitude,
    double? longitude,
    String? geocodeStatus,
    DateTime? geocodedAt,
    bool clearGeocode = false,
  }) => Site._(
    id: id,
    name: name ?? this.name,
    addressLine1: addressLine1 ?? this.addressLine1,
    addressLine2: addressLine2 ?? this.addressLine2,
    suburb: suburb ?? this.suburb,
    state: state ?? this.state,
    postcode: postcode ?? this.postcode,
    accessDetails: accessDetails ?? this.accessDetails,
    latitude: clearGeocode ? null : latitude ?? this.latitude,
    longitude: clearGeocode ? null : longitude ?? this.longitude,
    geocodeStatus: clearGeocode
        ? geocodeStatus
        : geocodeStatus ?? this.geocodeStatus,
    geocodedAt: clearGeocode ? null : geocodedAt ?? this.geocodedAt,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory Site.fromMap(Map<String, dynamic> map) => Site._(
    id: map['id'] as int,
    name: map['name'] as String?,
    addressLine1: map['addressLine1'] as String,
    addressLine2: map['addressLine2'] as String,
    suburb: map['suburb'] as String,
    state: map['state'] as String,
    postcode: map['postcode'] as String,
    accessDetails: map['accessDetails'] as String?,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    geocodeStatus: map['geocodeStatus'] as String?,
    geocodedAt: map['geocodedAt'] == null
        ? null
        : DateTime.tryParse(map['geocodedAt'] as String),
    createdDate: DateTime.parse(map['createdDate'] as String),
    modifiedDate: DateTime.parse(map['modifiedDate'] as String),
  );

  String get address =>
      joinAddressParts([addressLine1, addressLine2, suburb, state, postcode]);

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'addressLine1': addressLine1,
    'addressLine2': addressLine2,
    'suburb': suburb,
    'state': state,
    'postcode': postcode,
    'accessDetails': accessDetails,
    'latitude': latitude,
    'longitude': longitude,
    'geocodeStatus': geocodeStatus,
    'geocodedAt': geocodedAt?.toIso8601String(),
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
  };

  String abbreviated() => '$addressLine1, $suburb';

  String toGoogleMapsQuery() {
    final address = '$addressLine1, $addressLine2, $suburb, $state $postcode';
    final encodedAddress = Uri.encodeComponent(address);
    return 'https://www.google.com/maps/search/?api=1&query=$encodedAddress';
  }

  bool isEmpty() =>
      addressLine1.isEmpty &&
      addressLine2.isEmpty &&
      suburb.isEmpty &&
      state.isEmpty &&
      postcode.isEmpty &&
      Strings.isBlank(accessDetails);
}

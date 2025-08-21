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

import 'entity.dart';

class Site extends Entity<Site> {
  Site({
    required super.id,
    required this.addressLine1,
    required this.addressLine2,
    required this.suburb,
    required this.state,
    required this.postcode,
    required this.accessDetails,
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
  }) : super.forInsert();

  Site.forUpdate({
    required super.entity,
    required this.addressLine1,
    required this.addressLine2,
    required this.suburb,
    required this.state,
    required this.postcode,
    required this.accessDetails,
  }) : super.forUpdate();

  factory Site.fromMap(Map<String, dynamic> map) => Site(
    id: map['id'] as int,
    addressLine1: map['addressLine1'] as String,
    addressLine2: map['addressLine2'] as String,
    suburb: map['suburb'] as String,
    state: map['state'] as String,
    postcode: map['postcode'] as String,
    accessDetails: map['accessDetails'] as String?, // New field
    createdDate: DateTime.parse(map['createdDate'] as String),
    modifiedDate: DateTime.parse(map['modifiedDate'] as String),
  );
  String addressLine1;
  String addressLine2;
  String suburb;
  String state;
  String postcode;

  /// Hold info such as pin codes for lock boxes.
  String? accessDetails;

  String get address => Strings.join(
    [addressLine1, addressLine2, suburb, state, postcode],
    separator: ', ',
    excludeEmpty: true,
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'addressLine1': addressLine1,
    'addressLine2': addressLine2,
    'suburb': suburb,
    'state': state,
    'postcode': postcode,
    'accessDetails': accessDetails, // New field
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

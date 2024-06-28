import 'entity.dart';

class Site extends Entity<Site> {
  Site({
    required super.id,
    required this.addressLine1,
    required this.addressLine2,
    required this.suburb,
    required this.state,
    required this.postcode,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  Site.forInsert({
    required this.addressLine1,
    required this.addressLine2,
    required this.suburb,
    required this.state,
    required this.postcode,
  }) : super.forInsert();

  Site.forUpdate({
    required super.entity,
    required this.addressLine1,
    required this.addressLine2,
    required this.suburb,
    required this.state,
    required this.postcode,
  }) : super.forUpdate();

  factory Site.fromMap(Map<String, dynamic> map) => Site(
        id: map['id'] as int,
        addressLine1: map['addressLine1'] as String,
        addressLine2: map['addressLine2'] as String,
        suburb: map['suburb'] as String,
        state: map['state'] as String,
        postcode: map['postcode'] as String,
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
      );
  String addressLine1;
  String addressLine2;
  String suburb;
  String state;
  String postcode;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'addressLine1': addressLine1,
        'addressLine2': addressLine2,
        'suburb': suburb,
        'state': state,
        'postcode': postcode,
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
      postcode.isEmpty;
}

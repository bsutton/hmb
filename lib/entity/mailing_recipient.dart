/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'package:strings/strings.dart';

import '../util/dart/address_format.dart';
import 'entity.dart';

enum MailingDeliveryStatus {
  pending('Pending'),
  delivered('Delivered'),
  skipped('Skipped');

  const MailingDeliveryStatus(this.display);
  final String display;

  static MailingDeliveryStatus fromName(String? name) => MailingDeliveryStatus
      .values
      .firstWhere((value) => value.name == name, orElse: () => pending);
}

class MailingRecipient extends Entity<MailingRecipient> {
  final int mailingId;
  final int customerId;
  final int? contactId;
  final int? siteId;
  final String contactName;
  final String customerName;
  final String? siteName;
  final String addressLine1;
  final String addressLine2;
  final String suburb;
  final String state;
  final String postcode;
  final bool selected;
  final bool excluded;
  final int? routeOrder;
  final int? routeBatch;
  final MailingDeliveryStatus deliveryStatus;
  final DateTime? deliveredAt;
  final DateTime? skippedAt;

  MailingRecipient._({
    required super.id,
    required this.mailingId,
    required this.customerId,
    required this.contactId,
    required this.siteId,
    required this.contactName,
    required this.customerName,
    required this.siteName,
    required this.addressLine1,
    required this.addressLine2,
    required this.suburb,
    required this.state,
    required this.postcode,
    required this.selected,
    required this.excluded,
    required this.routeOrder,
    required this.routeBatch,
    required this.deliveryStatus,
    required this.deliveredAt,
    required this.skippedAt,
    required super.createdDate,
    required super.modifiedDate,
  });

  MailingRecipient.forInsert({
    required this.mailingId,
    required this.customerId,
    required this.contactId,
    required this.siteId,
    required this.contactName,
    required this.customerName,
    required this.siteName,
    required this.addressLine1,
    required this.addressLine2,
    required this.suburb,
    required this.state,
    required this.postcode,
    this.selected = true,
    this.excluded = false,
    this.routeOrder,
    this.routeBatch,
    this.deliveryStatus = MailingDeliveryStatus.pending,
    this.deliveredAt,
    this.skippedAt,
  }) : super.forInsert();

  bool get hasAddress =>
      hasSpecificAddressLine(addressLine1) && Strings.isNotBlank(suburb);

  static bool hasSpecificAddressLine(String addressLine1) =>
      Strings.isNotBlank(addressLine1) && RegExp(r'\d').hasMatch(addressLine1);

  bool get hasPartialAddress =>
      !hasAddress &&
      [
        addressLine1,
        addressLine2,
        suburb,
        state,
        postcode,
      ].any(Strings.isNotBlank);

  String get address =>
      joinAddressParts([addressLine1, addressLine2, suburb, state, postcode]);

  MailingRecipient copyWith({
    int? contactId,
    int? siteId,
    String? contactName,
    String? customerName,
    String? siteName,
    String? addressLine1,
    String? addressLine2,
    String? suburb,
    String? state,
    String? postcode,
    bool? selected,
    bool? excluded,
    int? routeOrder,
    int? routeBatch,
    MailingDeliveryStatus? deliveryStatus,
    DateTime? deliveredAt,
    DateTime? skippedAt,
    bool clearRoute = false,
    bool clearSite = false,
    bool clearDeliveredAt = false,
    bool clearSkippedAt = false,
  }) => MailingRecipient._(
    id: id,
    mailingId: mailingId,
    customerId: customerId,
    contactId: contactId ?? this.contactId,
    siteId: clearSite ? null : siteId ?? this.siteId,
    contactName: contactName ?? this.contactName,
    customerName: customerName ?? this.customerName,
    siteName: clearSite ? null : siteName ?? this.siteName,
    addressLine1: addressLine1 ?? this.addressLine1,
    addressLine2: addressLine2 ?? this.addressLine2,
    suburb: suburb ?? this.suburb,
    state: state ?? this.state,
    postcode: postcode ?? this.postcode,
    selected: selected ?? this.selected,
    excluded: excluded ?? this.excluded,
    routeOrder: clearRoute ? null : routeOrder ?? this.routeOrder,
    routeBatch: clearRoute ? null : routeBatch ?? this.routeBatch,
    deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    deliveredAt: clearDeliveredAt ? null : deliveredAt ?? this.deliveredAt,
    skippedAt: clearSkippedAt ? null : skippedAt ?? this.skippedAt,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory MailingRecipient.fromMap(Map<String, dynamic> map) =>
      MailingRecipient._(
        id: map['id'] as int,
        mailingId: map['mailing_id'] as int,
        customerId: map['customer_id'] as int,
        contactId: map['contact_id'] as int?,
        siteId: map['site_id'] as int?,
        contactName: map['contact_name'] as String? ?? '',
        customerName: map['customer_name'] as String? ?? '',
        siteName: map['site_name'] as String?,
        addressLine1: map['address_line_1'] as String? ?? '',
        addressLine2: map['address_line_2'] as String? ?? '',
        suburb: map['suburb'] as String? ?? '',
        state: map['state'] as String? ?? '',
        postcode: map['postcode'] as String? ?? '',
        selected: (map['selected'] as int? ?? 1) == 1,
        excluded: (map['excluded'] as int? ?? 0) == 1,
        routeOrder: map['route_order'] as int?,
        routeBatch: map['route_batch'] as int?,
        deliveryStatus: MailingDeliveryStatus.fromName(
          map['delivery_status'] as String?,
        ),
        deliveredAt: _date(map['delivered_at']),
        skippedAt: _date(map['skipped_at']),
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
      );

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value as String);

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'mailing_id': mailingId,
    'customer_id': customerId,
    'contact_id': contactId,
    'site_id': siteId,
    'contact_name': contactName,
    'customer_name': customerName,
    'site_name': siteName,
    'address_line_1': addressLine1,
    'address_line_2': addressLine2,
    'suburb': suburb,
    'state': state,
    'postcode': postcode,
    'selected': selected ? 1 : 0,
    'excluded': excluded ? 1 : 0,
    'route_order': routeOrder,
    'route_batch': routeBatch,
    'delivery_status': deliveryStatus.name,
    'delivered_at': deliveredAt?.toIso8601String(),
    'skipped_at': skippedAt?.toIso8601String(),
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
  };
}

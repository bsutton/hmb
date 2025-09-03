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

import 'package:money2/money2.dart';

import 'entity.dart';
import 'job_status.dart';

enum BillingType {
  timeAndMaterial('Time and Materials'),
  fixedPrice('Fixed Price');

  const BillingType(this.display);
  final String display;
}

class Job extends Entity<Job> {
  int? customerId;
  String summary;
  String description;
  String assumption;
  int? siteId;
  int? contactId;
  JobStatus status;
  Money? hourlyRate;
  Money? bookingFee;
  bool lastActive;
  BillingType billingType;
  bool bookingFeeInvoiced;
  int? billingContactId;

  Job._({
    required super.id,
    required this.customerId,
    required this.summary,
    required this.description,
    required this.assumption,
    required this.siteId,
    required this.contactId,
    required this.status,
    required this.hourlyRate,
    required this.bookingFee,
    required this.billingContactId,
    required this.lastActive,
    required super.createdDate,
    required super.modifiedDate,
    this.billingType = BillingType.timeAndMaterial,
    this.bookingFeeInvoiced = false,
  }) : super();

  Job.forInsert({
    required this.customerId,
    required this.summary,
    required this.description,
    required this.siteId,
    required this.contactId,
    required this.status,
    required this.hourlyRate,
    required this.bookingFee,
    required this.billingContactId,
    this.assumption = '',
    this.lastActive = false,
    this.billingType = BillingType.timeAndMaterial,
    this.bookingFeeInvoiced = false,
  }) : super.forInsert();

  Job copyWith({
    int? customerId,
    String? summary,
    String? description,
    String? assumption,
    int? siteId,
    int? contactId,
    JobStatus? status,
    Money? hourlyRate,
    Money? bookingFee,
    bool? lastActive,
    BillingType? billingType,
    bool? bookingFeeInvoiced,
    int? billingContactId,
  }) => Job._(
    id: id,
    customerId: customerId ?? this.customerId,
    summary: summary ?? this.summary,
    description: description ?? this.description,
    assumption: assumption ?? this.assumption,
    siteId: siteId ?? this.siteId,
    contactId: contactId ?? this.contactId,
    status: status ?? this.status,
    hourlyRate: hourlyRate ?? this.hourlyRate,
    bookingFee: bookingFee ?? this.bookingFee,
    billingContactId: billingContactId ?? this.billingContactId,
    lastActive: lastActive ?? this.lastActive,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
    billingType: billingType ?? this.billingType,
    bookingFeeInvoiced: bookingFeeInvoiced ?? this.bookingFeeInvoiced,
  );

  factory Job.fromMap(Map<String, dynamic> map) => Job._(
    id: map['id'] as int,
    customerId: map['customer_id'] as int?,
    summary: map['summary'] as String,
    description: map['description'] as String,
    assumption: map['assumption'] as String,
    siteId: map['site_id'] as int?,
    contactId: map['contact_id'] as int?,
    status: JobStatus.fromId(map['status_id'] as String),
    hourlyRate: Money.fromInt(map['hourly_rate'] as int? ?? 0, isoCode: 'AUD'),
    bookingFee: Money.fromInt(map['booking_fee'] as int? ?? 0, isoCode: 'AUD'),
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
    lastActive: (map['last_active'] as int) == 1,
    billingType: BillingType.values.firstWhere(
      (e) => e.name == (map['billing_type'] as String?),
      orElse: () => BillingType.timeAndMaterial,
    ),
    bookingFeeInvoiced: (map['booking_fee_invoiced'] as int) == 1,
    billingContactId: map['billing_contact_id'] as int?,
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'customer_id': customerId,
    'summary': summary,
    'description': description,
    'assumption': assumption,
    'site_id': siteId,
    'contact_id': contactId,
    'status_id': status.id,
    'hourly_rate': hourlyRate?.minorUnits.toInt(),
    'booking_fee': bookingFee?.minorUnits.toInt(),
    'last_active': lastActive ? 1 : 0,
    'billing_type': billingType.name,
    'booking_fee_invoiced': bookingFeeInvoiced ? 1 : 0,
    'billing_contact_id': billingContactId,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

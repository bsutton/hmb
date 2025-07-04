/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:money2/money2.dart';

import 'entity.dart';

enum BillingType {
  timeAndMaterial('Time and Materials'),
  fixedPrice('Fixed Price');

  const BillingType(this.display);
  final String display;
}

class Job extends Entity<Job> {
  Job({
    required super.id,
    required this.customerId,
    required this.summary,
    required this.description,
    required this.assumption,
    required this.siteId,
    required this.contactId,
    required this.jobStatusId,
    required this.hourlyRate,
    required this.bookingFee,
    required this.lastActive,
    required super.createdDate,
    required super.modifiedDate,
    required this.billingContactId,
    this.billingType = BillingType.timeAndMaterial,
    this.bookingFeeInvoiced = false,
  }) : super();

  Job.forInsert({
    required this.customerId,
    required this.summary,
    required this.description,
    required this.siteId,
    required this.contactId,
    required this.jobStatusId,
    required this.hourlyRate,
    required this.bookingFee,
    required this.billingContactId,
    this.assumption = '',
    this.lastActive = false,
    this.billingType = BillingType.timeAndMaterial,
    this.bookingFeeInvoiced = false,
  }) : super.forInsert();

  Job.forUpdate({
    required super.entity,
    required this.customerId,
    required this.summary,
    required this.description,
    required this.assumption,
    required this.siteId,
    required this.contactId,
    required this.jobStatusId,
    required this.hourlyRate,
    required this.bookingFee,
    required this.billingContactId,
    required this.bookingFeeInvoiced,
    this.lastActive = false,
    this.billingType = BillingType.timeAndMaterial,
  }) : super.forUpdate();

  factory Job.fromMap(Map<String, dynamic> map) => Job(
    id: map['id'] as int,
    customerId: map['customer_id'] as int?,
    summary: map['summary'] as String,
    description: map['description'] as String,
    assumption: map['assumption'] as String,
    siteId: map['site_id'] as int?,
    contactId: map['contact_id'] as int?,
    jobStatusId: map['job_status_id'] as int?,
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
    'job_status_id': jobStatusId,
    'hourly_rate': hourlyRate?.minorUnits.toInt(),
    'booking_fee': bookingFee?.minorUnits.toInt(),
    'last_active': lastActive ? 1 : 0,
    'billing_type': billingType.name,
    'booking_fee_invoiced': bookingFeeInvoiced ? 1 : 0,
    'billing_contact_id': billingContactId,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };

  int? customerId;
  String summary;
  String description;
  String assumption;
  int? siteId;
  int? contactId;
  int? jobStatusId;
  Money? hourlyRate;
  Money? bookingFee;
  bool lastActive;
  BillingType billingType;
  bool bookingFeeInvoiced;
  int? billingContactId;
}

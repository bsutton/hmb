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

import 'package:money2/money2.dart';

import '../util/dart/fixed_ex.dart';
import 'entity.dart';
import 'job_status.dart';

enum BillingType {
  timeAndMaterial('Time and Materials'),
  fixedPrice('Fixed Price'),

  /// doesn't show in the count of active jobs,
  /// doesn't show in the list of 'to be invoiced',
  /// you can't raise an invoice
  /// is exclude from the job list by default
  nonBillable('Non Billable');

  const BillingType(this.display);
  final String display;

  static BillingType fromName(String? name) => name == null
      ? BillingType.timeAndMaterial
      : BillingType.values.byName(name);
}

enum BillingParty {
  customer('Customer'),
  referrer('Referrer');

  const BillingParty(this.display);
  final String display;

  static BillingParty fromName(String? name) =>
      name == null ? BillingParty.customer : BillingParty.values.byName(name);
}

class Job extends Entity<Job> {
  int? customerId;
  bool isStock;
  int? referrerCustomerId;
  String summary;
  String description;
  String assumption;

  /// Notes about the job/client that are not show on invoices
  /// nor qutoes.
  String internalNotes;

  int? siteId;
  int? contactId;
  JobStatus status;
  Money? hourlyRate;
  Money? bookingFee;
  bool lastActive;
  BillingType billingType;
  bool bookingFeeInvoiced;
  int? billingContactId;
  int? referrerContactId;
  int? tenantContactId;
  BillingParty billingParty;
  Percentage estimateMargin;

  Job._({
    required super.id,
    required this.customerId,
    required this.referrerCustomerId,
    required this.summary,
    required this.description,
    required this.assumption,
    required this.internalNotes,
    required this.siteId,
    required this.contactId,
    required this.status,
    required this.hourlyRate,
    required this.bookingFee,
    required this.billingContactId,
    required this.referrerContactId,
    required this.tenantContactId,
    required this.billingParty,
    required this.estimateMargin,
    required this.lastActive,
    required super.createdDate,
    required super.modifiedDate,
    this.isStock = false,
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
    this.referrerCustomerId,
    this.referrerContactId,
    this.tenantContactId,
    this.billingParty = BillingParty.customer,
    Percentage? estimateMargin,
    this.isStock = false,
    this.assumption = '',
    this.internalNotes = '',
    this.lastActive = false,
    this.billingType = BillingType.timeAndMaterial,
    this.bookingFeeInvoiced = false,
  }) : estimateMargin = estimateMargin ?? Percentage.zero,
       super.forInsert();

  Job copyWith({
    int? customerId,
    bool? isStock,
    int? referrerCustomerId,
    String? summary,
    String? description,
    String? assumption,
    String? notes,
    int? siteId,
    int? contactId,
    JobStatus? status,
    Money? hourlyRate,
    Money? bookingFee,
    bool? lastActive,
    BillingType? billingType,
    bool? bookingFeeInvoiced,
    int? billingContactId,
    int? referrerContactId,
    int? tenantContactId,
    BillingParty? billingParty,
    Percentage? estimateMargin,
  }) => Job._(
    id: id,
    customerId: customerId ?? this.customerId,
    isStock: isStock ?? this.isStock,
    referrerCustomerId: referrerCustomerId ?? this.referrerCustomerId,
    summary: summary ?? this.summary,
    description: description ?? this.description,
    assumption: assumption ?? this.assumption,
    internalNotes: notes ?? internalNotes,
    siteId: siteId ?? this.siteId,
    contactId: contactId ?? this.contactId,
    status: status ?? this.status,
    hourlyRate: hourlyRate ?? this.hourlyRate,
    bookingFee: bookingFee ?? this.bookingFee,
    billingContactId: billingContactId ?? this.billingContactId,
    referrerContactId: referrerContactId ?? this.referrerContactId,
    tenantContactId: tenantContactId ?? this.tenantContactId,
    billingParty: billingParty ?? this.billingParty,
    estimateMargin: estimateMargin ?? this.estimateMargin,
    lastActive: lastActive ?? this.lastActive,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
    billingType: billingType ?? this.billingType,
    bookingFeeInvoiced: bookingFeeInvoiced ?? this.bookingFeeInvoiced,
  );

  factory Job.fromMap(Map<String, dynamic> map) => Job._(
    id: map['id'] as int,
    customerId: map['customer_id'] as int?,
    isStock: (map['is_stock'] as int? ?? 0) == 1,
    referrerCustomerId: map['referrer_customer_id'] as int?,
    summary: map['summary'] as String,
    description: map['description'] as String,
    assumption: map['assumption'] as String,
    internalNotes: map['internal_notes'] as String? ?? '',
    siteId: map['site_id'] as int?,
    contactId: map['contact_id'] as int?,
    status: JobStatus.fromId(map['status_id'] as String),
    hourlyRate: Money.fromInt(map['hourly_rate'] as int? ?? 0, isoCode: 'AUD'),
    bookingFee: Money.fromInt(map['booking_fee'] as int? ?? 0, isoCode: 'AUD'),
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
    lastActive: (map['last_active'] as int) == 1,
    billingType: BillingType.fromName(map['billing_type'] as String?),
    bookingFeeInvoiced: (map['booking_fee_invoiced'] as int) == 1,
    billingContactId: map['billing_contact_id'] as int?,
    referrerContactId: map['referrer_contact_id'] as int?,
    tenantContactId: map['tenant_contact_id'] as int?,
    billingParty: BillingParty.fromName(map['billing_party'] as String?),
    estimateMargin: Percentage.fromInt(
      map['estimate_margin'] as int? ?? 0,
      decimalDigits: 3,
    ),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'customer_id': customerId,
    'is_stock': isStock ? 1 : 0,
    'referrer_customer_id': referrerCustomerId,
    'summary': summary,
    'description': description,
    'assumption': assumption,
    'internal_notes': internalNotes,
    'site_id': siteId,
    'contact_id': contactId,
    'status_id': status.id,
    'hourly_rate': hourlyRate?.minorUnits.toInt(),
    'booking_fee': bookingFee?.minorUnits.toInt(),
    'last_active': lastActive ? 1 : 0,
    'billing_type': billingType.name,
    'booking_fee_invoiced': bookingFeeInvoiced ? 1 : 0,
    'billing_contact_id': billingContactId,
    'referrer_contact_id': referrerContactId,
    'tenant_contact_id': tenantContactId,
    'billing_party': billingParty.name,
    'estimate_margin': estimateMargin.threeDigits().minorUnits.toInt(),
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

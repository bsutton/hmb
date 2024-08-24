import 'package:money2/money2.dart';

import 'entity.dart';

class Job extends Entity<Job> {
  Job({
    required super.id,
    required this.customerId,
    required this.summary,
    required this.description,
    required this.startDate,
    required this.siteId,
    required this.contactId,
    required this.jobStatusId,
    required this.hourlyRate,
    required this.callOutFee,
    required this.lastActive, // New field for Last Active
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  Job.forInsert({
    required this.customerId,
    required this.summary,
    required this.description,
    required this.startDate,
    required this.siteId,
    required this.contactId,
    required this.jobStatusId,
    required this.hourlyRate,
    required this.callOutFee,
    this.lastActive = false, // New field for Last Active
  }) : super.forInsert();

  Job.forUpdate({
    required super.entity,
    required this.customerId,
    required this.summary,
    required this.description,
    required this.startDate,
    required this.siteId,
    required this.contactId,
    required this.jobStatusId,
    required this.hourlyRate,
    required this.callOutFee,
    this.lastActive = false, //
  }) : super.forUpdate();

  factory Job.fromMap(Map<String, dynamic> map) => Job(
        id: map['id'] as int,
        customerId: map['customer_id'] as int?,
        summary: map['summary'] as String,
        description: map['description'] as String,
        startDate: DateTime.parse(map['startDate'] as String),
        siteId: map['site_id'] as int?,
        contactId: map['contact_id'] as int?,
        jobStatusId: map['job_status_id'] as int?,
        hourlyRate:
            Money.fromInt(map['hourly_rate'] as int? ?? 0, isoCode: 'AUD'),
        callOutFee:
            Money.fromInt(map['call_out_fee'] as int? ?? 0, isoCode: 'AUD'),
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
        lastActive: map['last_active'] == 1,
      );

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'customer_id': customerId,
        'summary': summary,
        'description': description,
        'startDate': startDate.toIso8601String(),
        'site_id': siteId,
        'job_status_id': jobStatusId,
        'contact_id': contactId,
        'hourly_rate': hourlyRate?.minorUnits.toInt(),
        'call_out_fee': callOutFee?.minorUnits.toInt(),
        'last_active': lastActive ? 1 : 0, // New field for Last Active
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate.toIso8601String(),
      };

  int? customerId;
  DateTime startDate;
  String summary;
  String description;
  int? siteId;
  int? contactId;
  int? jobStatusId;
  Money? hourlyRate;
  Money? callOutFee;
  bool lastActive; // New field for Last Active
}

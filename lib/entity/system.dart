import 'package:money2/money2.dart';

import 'entity.dart';

class System extends Entity<System> {
  System({
    required super.id,
    required this.fromEmail,
    required this.bsb,
    required this.accountNo,
    required this.addressLine1,
    required this.addressLine2,
    required this.suburb,
    required this.state,
    required this.postcode,
    required this.mobileNumber,
    required this.landLine,
    required this.officeNumber,
    required this.emailAddress,
    required this.webUrl,
    required this.defaultHourlyRate,
    required this.termsUrl,
    required this.defaultCallOutFee,
    required this.simCardNo,
    required this.xeroClientId,
    required this.xeroClientSecret,
    required this.businessName, // Added business name field
    required this.businessNumber, // Added business number field
    required this.businessNumberLabel, // Added business number label field
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  System.forInsert(
      {required this.fromEmail,
      required this.bsb,
      required this.accountNo,
      required this.addressLine1,
      required this.addressLine2,
      required this.suburb,
      required this.state,
      required this.postcode,
      required this.mobileNumber,
      required this.landLine,
      required this.officeNumber,
      required this.emailAddress,
      required this.webUrl,
      required this.defaultHourlyRate,
      required this.termsUrl,
      required this.defaultCallOutFee,
      required this.simCardNo,
      required this.xeroClientId,
      required this.xeroClientSecret,
      required this.businessName, // Added business name field
      required this.businessNumber, // Added business number field
      required this.businessNumberLabel}) // Added business number label field
      : super.forInsert();

  System.forUpdate(
      {required super.entity,
      required this.fromEmail,
      required this.bsb,
      required this.accountNo,
      required this.addressLine1,
      required this.addressLine2,
      required this.suburb,
      required this.state,
      required this.postcode,
      required this.mobileNumber,
      required this.landLine,
      required this.officeNumber,
      required this.emailAddress,
      required this.webUrl,
      required this.defaultHourlyRate,
      required this.termsUrl,
      required this.defaultCallOutFee,
      required this.simCardNo,
      required this.xeroClientId,
      required this.xeroClientSecret,
      required this.businessName, // Added business name field
      required this.businessNumber, // Added business number field
      required this.businessNumberLabel}) // Added business number label field
      : super.forUpdate();

  factory System.fromMap(Map<String, dynamic> map) => System(
        id: map['id'] as int,
        fromEmail: map['fromEmail'] as String?,
        bsb: map['BSB'] as String?,
        accountNo: map['accountNo'] as String?,
        addressLine1: map['addressLine1'] as String?,
        addressLine2: map['addressLine2'] as String?,
        suburb: map['suburb'] as String?,
        state: map['state'] as String?,
        postcode: map['postcode'] as String?,
        mobileNumber: map['mobileNumber'] as String?,
        landLine: map['landLine'] as String?,
        officeNumber: map['officeNumber'] as String?,
        emailAddress: map['emailAddress'] as String?,
        webUrl: map['webUrl'] as String?,
        defaultHourlyRate: Money.fromInt(
            map['default_hourly_rate'] as int? ?? 0,
            isoCode: 'AUD'),
        termsUrl: map['terms_url'] as String?,
        defaultCallOutFee: Money.fromInt(
            map['default_call_out_fee'] as int? ?? 0,
            isoCode: 'AUD'),
        simCardNo: map['sim_card_no'] as int?,
        xeroClientId: map['xero_client_id'] as String?,
        xeroClientSecret: map['xero_client_secret'] as String?,
        businessName:
            map['business_name'] as String?, // Added business name field
        businessNumber:
            map['business_number'] as String?, // Added business number field
        businessNumberLabel: map['business_number_label']
            as String?, // Added business number label field
        createdDate: DateTime.tryParse((map['createdDate']) as String? ?? '') ??
            DateTime.now(),
        modifiedDate:
            DateTime.tryParse((map['modifiedDate']) as String? ?? '') ??
                DateTime.now(),
      );

  String? fromEmail;
  String? bsb;
  String? accountNo;
  String? addressLine1;
  String? addressLine2;
  String? suburb;
  String? state;
  String? postcode;
  String? mobileNumber;
  String? landLine;
  String? officeNumber;
  String? emailAddress;
  String? webUrl;
  Money? defaultHourlyRate; // in cents
  String? termsUrl; // link to terms and conditions
  Money? defaultCallOutFee; // in cents
  int? simCardNo;
  String? xeroClientId;
  String? xeroClientSecret;
  String? businessName; // Added business name field
  String? businessNumber; // Added business number field
  String? businessNumberLabel; // Added business number label field

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'fromEmail': fromEmail,
        'BSB': bsb,
        'accountNo': accountNo,
        'addressLine1': addressLine1,
        'addressLine2': addressLine2,
        'suburb': suburb,
        'state': state,
        'postcode': postcode,
        'mobileNumber': mobileNumber,
        'landLine': landLine,
        'officeNumber': officeNumber,
        'emailAddress': emailAddress,
        'webUrl': webUrl,
        'default_hourly_rate': defaultHourlyRate?.minorUnits.toInt(),
        'terms_url': termsUrl,
        'default_call_out_fee': defaultCallOutFee?.minorUnits.toInt(),
        'sim_card_no': simCardNo,
        'xero_client_id': xeroClientId,
        'xero_client_secret': xeroClientSecret,
        'business_name': businessName, // Added business name field
        'business_number': businessNumber, // Added business number field
        'business_number_label':
            businessNumberLabel, // Added business number label field
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate.toIso8601String(),
      };
}

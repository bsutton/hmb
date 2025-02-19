import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../util/local_date.dart';
import '../util/measurement_type.dart';
import 'entity.dart';
import 'operating_hours.dart';

enum LogoAspectRatio {
  square(100, 100),
  portrait(80, 120),
  landscape(120, 80);

  const LogoAspectRatio(this.width, this.height);

  final int width;
  final int height;

  static LogoAspectRatio fromName(String? name) {
    switch (name) {
      case 'square':
        return LogoAspectRatio.square;
      case 'portrait':
        return LogoAspectRatio.portrait;
      case 'landscape':
        return LogoAspectRatio.landscape;
      default:
        return LogoAspectRatio.square;
    }
  }
}

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
    required this.defaultBookingFee,
    required this.simCardNo,
    required this.xeroClientId,
    required this.xeroClientSecret,
    required this.businessName,
    required this.businessNumber,
    required this.businessNumberLabel,
    required this.countryCode,
    required this.paymentLinkUrl,
    required this.showBsbAccountOnInvoice,
    required this.showPaymentLinkOnInvoice,
    required this.preferredUnitSystem,
    required this.logoPath,
    required this.logoAspectRatio,
    required this.billingColour,
    required this.paymentTermsInDays,
    required this.paymentOptions,
    required this.firstname, // New field
    required this.surname, // New field
    required super.createdDate,
    required super.modifiedDate,
    this.operatingHours, // <<--- New field for operating days/hours
  }) : super();

  System.forInsert({
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
    required this.defaultBookingFee,
    required this.simCardNo,
    required this.xeroClientId,
    required this.xeroClientSecret,
    required this.businessName,
    required this.businessNumber,
    required this.businessNumberLabel,
    required this.countryCode,
    required this.paymentLinkUrl,
    required this.showBsbAccountOnInvoice,
    required this.showPaymentLinkOnInvoice,
    required this.billingColour,
    required this.paymentTermsInDays,
    required this.paymentOptions,
    this.preferredUnitSystem = PreferredUnitSystem.metric,
    this.logoPath = '',
    this.logoAspectRatio = LogoAspectRatio.square,
    this.firstname, // New field
    this.surname, // New field
    this.operatingHours, // <<--- New field for operating days/hours
  }) : super.forInsert();

  System.forUpdate({
    required super.entity,
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
    required this.defaultBookingFee,
    required this.simCardNo,
    required this.xeroClientId,
    required this.xeroClientSecret,
    required this.businessName,
    required this.businessNumber,
    required this.businessNumberLabel,
    required this.countryCode,
    required this.paymentLinkUrl,
    required this.showBsbAccountOnInvoice,
    required this.showPaymentLinkOnInvoice,
    required this.preferredUnitSystem,
    required this.logoPath,
    required this.logoAspectRatio,
    required this.billingColour,
    required this.paymentTermsInDays,
    required this.paymentOptions,
    this.firstname, // New field
    this.surname, // New field
    this.operatingHours, // <<--- New field for operating days/hours
  }) : super.forUpdate();

  factory System.fromMap(Map<String, dynamic> map) => System(
    id: map['id'] as int,
    fromEmail: map['from_email'] as String?,
    bsb: map['bsb'] as String?,
    accountNo: map['account_no'] as String?,
    addressLine1: map['address_line_1'] as String?,
    addressLine2: map['address_line_2'] as String?,
    suburb: map['suburb'] as String?,
    state: map['state'] as String?,
    postcode: map['postcode'] as String?,
    mobileNumber: map['mobile_number'] as String?,
    landLine: map['landline'] as String?,
    officeNumber: map['office_number'] as String?,
    emailAddress: map['email_address'] as String?,
    webUrl: map['web_url'] as String?,
    defaultHourlyRate: Money.fromInt(
      map['default_hourly_rate'] as int? ?? 0,
      isoCode: 'AUD',
    ),
    termsUrl: map['terms_url'] as String?,
    defaultBookingFee: Money.fromInt(
      map['default_booking_fee'] as int? ?? 0,
      isoCode: 'AUD',
    ),
    simCardNo: map['sim_card_no'] as int?,
    xeroClientId: map['xero_client_id'] as String?,
    xeroClientSecret: map['xero_client_secret'] as String?,
    businessName: map['business_name'] as String?,
    businessNumber: map['business_number'] as String?,
    businessNumberLabel: map['business_number_label'] as String?,
    countryCode: map['country_code'] as String?,
    paymentLinkUrl: map['payment_link_url'] as String?,
    showBsbAccountOnInvoice: map['show_bsb_account_on_invoice'] == 1,
    showPaymentLinkOnInvoice: map['show_payment_link_on_invoice'] == 1,
    preferredUnitSystem:
        (map['use_metric_units'] == 1)
            ? PreferredUnitSystem.metric
            : PreferredUnitSystem.imperial,
    logoPath: map['logo_path'] as String? ?? '',
    logoAspectRatio: LogoAspectRatio.fromName(
      map['logo_aspect_ratio'] as String?,
    ),
    billingColour: map['billing_colour'] as int? ?? 0xFF000000,
    paymentTermsInDays: map['payment_terms_in_days'] as int? ?? 3,
    paymentOptions: map['payment_options'] as String? ?? '',
    firstname: map['firstname'] as String?,
    surname: map['surname'] as String?,
    operatingHours: map['operating_hours'] as String?, // <<--- New field
    createdDate:
        DateTime.tryParse(map['created_date'] as String? ?? '') ??
        DateTime.now(),
    modifiedDate:
        DateTime.tryParse(map['modified_date'] as String? ?? '') ??
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
  Money? defaultHourlyRate;
  String? termsUrl;
  Money? defaultBookingFee;
  int? simCardNo;
  String? xeroClientId;
  String? xeroClientSecret;
  String? businessName;
  String? businessNumber;
  String? businessNumberLabel;
  String? countryCode;
  String? paymentLinkUrl;
  bool? showBsbAccountOnInvoice;
  bool? showPaymentLinkOnInvoice;
  PreferredUnitSystem preferredUnitSystem;
  String logoPath;
  LogoAspectRatio logoAspectRatio;
  int billingColour;
  int paymentTermsInDays;
  String paymentOptions;
  String? firstname;
  String? surname;
  String? operatingHours; // <<--- New field

  void setOperatingHours(OperatingHours schedule) {
    operatingHours = schedule.toJson();
    // Save
    // `system` to the DB as usual
  }

  OperatingHours getOperatingHours() => OperatingHours.fromJson(operatingHours);

  String? get bestPhone =>
      Strings.isNotBlank(mobileNumber)
          ? mobileNumber
          : Strings.isNotBlank(landLine)
          ? landLine
          : officeNumber;

  String get address => Strings.join(
    [addressLine1, addressLine2, suburb, state, postcode],
    separator: ', ',
    excludeEmpty: true,
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'from_email': fromEmail,
    'bsb': bsb,
    'account_no': accountNo,
    'address_line_1': addressLine1,
    'address_line_2': addressLine2,
    'suburb': suburb,
    'state': state,
    'postcode': postcode,
    'mobile_number': mobileNumber,
    'landline': landLine,
    'office_number': officeNumber,
    'email_address': emailAddress,
    'web_url': webUrl,
    'default_hourly_rate': defaultHourlyRate?.minorUnits.toInt(),
    'terms_url': termsUrl,
    'default_booking_fee': defaultBookingFee?.minorUnits.toInt(),
    'sim_card_no': simCardNo,
    'xero_client_id': xeroClientId,
    'xero_client_secret': xeroClientSecret,
    'business_name': businessName,
    'business_number': businessNumber,
    'business_number_label': businessNumberLabel,
    'country_code': countryCode,
    'payment_link_url': paymentLinkUrl,
    'show_bsb_account_on_invoice': showBsbAccountOnInvoice ?? true ? 1 : 0,
    'show_payment_link_on_invoice': showPaymentLinkOnInvoice ?? true ? 1 : 0,
    'use_metric_units':
        preferredUnitSystem == PreferredUnitSystem.metric ? 1 : 0,
    'logo_path': logoPath,
    'logo_aspect_ratio': logoAspectRatio.name,
    'billing_colour': billingColour,
    'payment_terms_in_days': paymentTermsInDays,
    'payment_options': paymentOptions,
    'firstname': firstname,
    'surname': surname,
    'operating_hours': operatingHours, // <<--- New field
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

enum DayName {
  mon('Monday', 'Mon'),
  tue('Tuesday', 'Tue'),
  wed('Wednesday', 'Wed'),
  thu('Thursday', 'Thu'),
  fri('Friday', 'Fri'),
  sat('Saturday', 'Sat'),
  sun('Sunday', 'Sun');

  const DayName(this.displayName, this.shortName);
  final String displayName;
  final String shortName;

  /// Returns the Dart enum name (e.g., "mon") as the JSON string.
  String toJson() => name;

  /// Looks up the appropriate DayName based on the enum name string (e.g., "mon").
  /// Throws a StateError if the provided dayStr doesn't match any known enum.
  static DayName fromJson(String dayStr) =>
      DayName.values.firstWhere((e) => e.name == dayStr);

  static DayName fromIndex(int index) => DayName.values[index];

  static DayName fromDate(LocalDate when) => DayName.fromWeekDay(when.weekday);

  /// From the 1 based [dayOfWeek] where Monday is 1.
  static DayName fromWeekDay(int dayOfWeek) => DayName.values[dayOfWeek - 1];
}

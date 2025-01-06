import 'dart:convert';

import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../dao/dao_job_event.dart';
import '../util/date_time_ex.dart';
import '../util/local_date.dart';
import '../util/local_time.dart';
import '../util/measurement_type.dart';
import 'entity.dart';
import 'job_event.dart';

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
        preferredUnitSystem: (map['use_metric_units'] == 1)
            ? PreferredUnitSystem.metric
            : PreferredUnitSystem.imperial,
        logoPath: map['logo_path'] as String? ?? '',
        logoAspectRatio:
            LogoAspectRatio.fromName(map['logo_aspect_ratio'] as String?),
        billingColour: map['billing_colour'] as int? ?? 0xFF000000,
        paymentTermsInDays: map['payment_terms_in_days'] as int? ?? 3,
        paymentOptions: map['payment_options'] as String? ?? '',
        firstname: map['firstname'] as String?,
        surname: map['surname'] as String?,
        operatingHours: map['operating_hours'] as String?, // <<--- New field
        createdDate: DateTime.tryParse(map['created_date'] as String? ?? '') ??
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

  String? get bestPhone => Strings.isNotBlank(mobileNumber)
      ? mobileNumber
      : Strings.isNotBlank(landLine)
          ? landLine
          : officeNumber;

  String get address =>
      Strings.join([addressLine1, addressLine2, suburb, state, postcode],
          separator: ', ', excludeEmpty: true);

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
        'show_payment_link_on_invoice':
            showPaymentLinkOnInvoice ?? true ? 1 : 0,
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

class OperatingDay {
  // e.g. "17:00"

  OperatingDay({
    required this.dayName,
    this.start,
    this.end,
    this.open = true,
  });

  /// Construct from a JSON map, expecting:
  /// {
  ///   "dayName": "mon",
  ///   "start": "08:00",
  ///   "end": "17:00"
  /// }
  factory OperatingDay.fromJson(Map<String, dynamic> json) => OperatingDay(
        dayName: DayName.fromJson(json['dayName'] as String),
        start: const LocalTimeConverter().fromJson(json['start'] as String?),
        end: const LocalTimeConverter().fromJson(json['end'] as String?),
        open: ((json['open'] as int?) ?? 1) == 1,
      );
  final DayName dayName;
  LocalTime? start; // e.g. "08:00"
  LocalTime? end;
  bool open;

  /// Convert this OperatingDay instance back to a JSON-like map.
  Map<String, dynamic> toJson() => {
        'dayName': dayName.toJson(),
        'start': const LocalTimeConverter().toJson(start),
        'end': const LocalTimeConverter().toJson(end),
        'open': open ? 1 : 0,
      };
}

class OperatingHours {
  OperatingHours({required this.days}) {
    final missing = <DayName>[];
    // back fill any missing days
    // this is required when we first populate the system table
    for (final day in DayName.values) {
      if (!days.containsKey(day)) {
        missing.add(day);
      }
    }

    for (final missed in missing) {
      days[missed] = OperatingDay(dayName: missed);
    }
  }

  /// Builds an OperatingHours instance from a JSON string.
  /// If the string is null/empty, returns an empty list.
  factory OperatingHours.fromJson(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) {
      return OperatingHours(days: <DayName, OperatingDay>{});
    }

    final decoded = jsonDecode(jsonStr) as List<dynamic>;
// Convert the decoded list into a Map keyed by `DayName`.
    final dayMap = {
      for (final item in decoded)
        OperatingDay.fromJson(item as Map<String, dynamic>).dayName:
            OperatingDay.fromJson(item),
    };

    return OperatingHours(days: dayMap);
  }

  /// A Map of  OperatingDay objects, one for each day you operate.
  /// The key is the short day name. e.g. Mon
  ///
  final Map<DayName, OperatingDay> days;

  /// Converts the OperatingHours instance back to a JSON string.
  String toJson() {
    // Convert the map values (OperatingDay) to a list of maps (JSON format).
    final listToEncode =
        days.values.map((operatingDay) => operatingDay.toJson()).toList();
    return jsonEncode(listToEncode);
  }

  /// Get the [OperatingDay] for the [dayName]
  OperatingDay day(DayName dayName) => days[dayName]!;

  /// True if at least one day of the week is marked as open.
  bool noOpenDays() => openList.where((open) => open).toList().isEmpty;

  /// An ordered list of the days that we are open - starting from monday
  List<bool> get openList =>
      days.values.map<bool>((hours) => hours.open).toList();

  /// True if the opening hours incude sat or sun
  bool openOnWeekEnd() =>
      openList[DayName.sat.index] || openList[DayName.sun.index];

  Future<bool> isOpen(LocalDate targetDate) async {
    final dayOfWeek = targetDate.date.weekday;

    var open = isDayOfWeekOpen(dayOfWeek);

    if (!open) {
      /// if the day isn't normally open we still need
      /// to check for events scheduled out of normal hours.

      /// special check for an event on the out of hours day.
      open = (await DaoJobEvent()
              .getEventsInRange(targetDate, targetDate.addDays(1)))
          .isNotEmpty;
    }
    return open;
  }

  bool isDayOfWeekOpen(int dayOfWeek) {
    final dayName = DayName.fromWeekDay(dayOfWeek);
    final operatingDay = day(dayName);

    return operatingDay.open;
  }

  Future<LocalDate> getNextOpenDate(LocalDate currentDate) async {
    // Start from the current date
    var date = currentDate;

    // Loop for a maximum of 7 days (one week) to find the next open day
    for (var i = 0; i < 7; i++) {
      // Check if the current day is open
      if (await isOpen(date)) {
        return date; // Return the first open day
      }

      // Move to the next day
      date = date.add(const Duration(days: 1));
    }

    // If no open day is found within the next 7 days (unlikely), throw an error
    throw StateError('No open days found within the next week.');
  }

  /// Example implementation for going backward to the previous open date.
  /// Similar logic to getNextOpenDate but in reverse.
  Future<LocalDate> getPreviousOpenDate(LocalDate fromDate) async {
    // Try up to 7 days backward (or whatever limit you prefer)
    var date = fromDate;
    for (var i = 0; i < 7; i++) {
      if (await isOpen(date)) {
        return date;
      }
      date = date.subtract(const Duration(days: 1));
    }
    // If everything is closed for a whole week, handle gracefully or throw:
    throw StateError('No open day found within the past 7 days.');
  }

  /// True if the [event] is fully within the normal operating hours.

  bool inOperatingHours(JobEvent event) {
    // 1) Check if the event is on a single day.
    //    If it spans multiple calendar days, return false (or handle specially).
    if (event.start.toLocalDate() != event.end.toLocalDate()) {
      return false;
    }

    // 2) Ensure that day is open in OperatingHours.
    //    If it's closed, return false right away.
    final dayOfWeek = event.start.weekday; // Monday=1, Sunday=7
    if (!isDayOfWeekOpen(dayOfWeek)) {
      return false;
    }

    // 3) Retrieve the OperatingDay for that weekday.
    final dayName = DayName.fromWeekDay(dayOfWeek);
    final operatingDay = day(dayName);

    // If, for some reason, `operatingDay.open` is false, return false.
    if (!operatingDay.open) {
      return false;
    }

    // 4) Compare the event’s time range to the day’s start/end times.
    //    If either start or end is null, treat as “no configured hours,” i.e., closed.
    if (operatingDay.start == null || operatingDay.end == null) {
      return false;
    }

    // 5) Check that the event starts after (or exactly at) opening
    //    AND ends before (or exactly at) closing.
    final eventStart = event.start.toLocalTime();
    final eventEnd = event.end.toLocalTime();
    final openTime = operatingDay.start!;
    final closeTime = operatingDay.end!;

    final startsTooEarly = eventStart.isBefore(openTime);
    final endsTooLate = eventEnd.isAfter(closeTime);

    if (startsTooEarly || endsTooLate) {
      return false;
    }

    return true;
  }
}

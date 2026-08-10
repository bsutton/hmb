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

import 'package:meta/meta.dart';
import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../util/dart/address_format.dart';
import '../util/dart/local_date.dart';
import '../util/dart/measurement_type.dart';
import 'entity.dart';
import 'operating_hours.dart';

enum RichTextRemoved {
  notYet(0),
  job(1),
  quote(2);

  final int ordinal;
  const RichTextRemoved(this.ordinal);

  static RichTextRemoved fromOrdinal(int? n) {
    if (n == null) {
      return RichTextRemoved.notYet;
    }
    for (final e in RichTextRemoved.values) {
      if (e.ordinal == n) {
        return e;
      }
    }
    return RichTextRemoved.notYet;
  }
}

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
        {
          return LogoAspectRatio.square;
        }
      case 'portrait':
        {
          return LogoAspectRatio.portrait;
        }
      case 'landscape':
        {
          return LogoAspectRatio.landscape;
        }
      default:
        {
          return LogoAspectRatio.square;
        }
    }
  }
}

enum SmtpProvider {
  custom('Custom SMTP'),
  gmail('Gmail'),
  outlook('Microsoft 365/Outlook'),
  icloud('iCloud Mail');

  const SmtpProvider(this.label);

  final String label;

  static SmtpProvider fromName(String? name) {
    for (final provider in values) {
      if (provider.name == name) {
        return provider;
      }
    }
    return SmtpProvider.custom;
  }
}

enum SmtpAuthMode {
  password('Password/app password'),
  googleOAuth('Google OAuth');

  const SmtpAuthMode(this.label);

  final String label;

  static SmtpAuthMode fromName(String? name) {
    for (final mode in values) {
      if (mode.name == name) {
        return mode;
      }
    }
    return SmtpAuthMode.password;
  }
}

class System extends Entity<System> {
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
  Percentage? defaultProfitMargin;
  int? simCardNo;
  String? xeroClientId;
  String? xeroClientSecret;

  /// Used to categorise invoice lineItems sent
  /// to the external accounting package.
  String? invoiceLineRevenueAccountCode;
  String? invoiceLineInventoryItemCode;
  bool enableXeroIntegration;
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
  int photoCacheMaxMb;
  int paymentTermsInDays;
  String paymentOptions;
  String? firstname;
  String? surname;
  String? operatingHours;

  /// OAuth2 tokens for ChatGPT API
  String? chatgptAccessToken;
  String? chatgptRefreshToken;
  DateTime? chatgptTokenExpiry;

  /// OpenAI API key for ChatGPT task/summary extraction.
  String? openaiApiKey;

  /// Google Maps Platform API key for geocoding and route optimisation.
  String? googleMapsApiKey;

  /// ihserver integration settings
  String? ihserverUrl;
  String? ihserverToken;
  bool enableIhserverIntegration;

  /// SMTP email settings. The password is stored in secure storage.
  SmtpProvider smtpProvider;
  SmtpAuthMode smtpAuthMode;
  String? smtpHost;
  int smtpPort;
  String? smtpUsername;
  String? smtpPassword;
  String? smtpFromEmail;
  String? smtpGoogleOAuthClientId;
  bool smtpUseSsl;

  /// Tracks removal of fleather rich-text fields using an ordinal enum.
  RichTextRemoved richTextRemoved;

  System._({
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
    required this.defaultProfitMargin,
    required this.simCardNo,
    required this.xeroClientId,
    required this.xeroClientSecret,
    required this.invoiceLineRevenueAccountCode,
    required this.invoiceLineInventoryItemCode,
    required this.enableXeroIntegration,
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
    required this.photoCacheMaxMb,
    required this.paymentTermsInDays,
    required this.paymentOptions,
    required this.firstname,
    required this.surname,
    required this.chatgptAccessToken,
    required this.chatgptRefreshToken,
    required this.chatgptTokenExpiry,
    required this.openaiApiKey,
    required this.googleMapsApiKey,
    required this.ihserverUrl,
    required this.ihserverToken,
    required this.enableIhserverIntegration,
    required this.smtpProvider,
    required this.smtpAuthMode,
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpUsername,
    required this.smtpPassword,
    required this.smtpFromEmail,
    required this.smtpGoogleOAuthClientId,
    required this.smtpUseSsl,
    required super.createdDate,
    required super.modifiedDate,
    required this.richTextRemoved,
    this.operatingHours,
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
    required this.invoiceLineRevenueAccountCode,
    required this.invoiceLineInventoryItemCode,
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
    required this.richTextRemoved,
    this.defaultProfitMargin,
    this.photoCacheMaxMb = 100,
    this.enableXeroIntegration = true,
    this.preferredUnitSystem = PreferredUnitSystem.metric,
    this.logoPath = '',
    this.logoAspectRatio = LogoAspectRatio.square,
    this.firstname,
    this.surname,
    this.operatingHours,
    this.chatgptAccessToken,
    this.chatgptRefreshToken,
    this.chatgptTokenExpiry,
    this.openaiApiKey,
    this.googleMapsApiKey,
    this.ihserverUrl,
    this.ihserverToken,
    this.enableIhserverIntegration = false,
    this.smtpProvider = SmtpProvider.custom,
    this.smtpAuthMode = SmtpAuthMode.password,
    this.smtpHost,
    this.smtpPort = 587,
    this.smtpUsername,
    this.smtpPassword,
    this.smtpFromEmail,
    this.smtpGoogleOAuthClientId,
    this.smtpUseSsl = false,
  }) : super.forInsert();

  System copyWith({
    String? fromEmail,
    String? bsb,
    String? accountNo,
    String? addressLine1,
    String? addressLine2,
    String? suburb,
    String? state,
    String? postcode,
    String? mobileNumber,
    String? landLine,
    String? officeNumber,
    String? emailAddress,
    String? webUrl,
    Money? defaultHourlyRate,
    String? termsUrl,
    Money? defaultBookingFee,
    Percentage? defaultProfitMargin,
    int? simCardNo,
    String? xeroClientId,
    String? xeroClientSecret,
    String? invoiceLineRevenueAccountCode,
    String? invoiceLineInventoryItemCode,
    bool? enableXeroIntegration,
    String? businessName,
    String? businessNumber,
    String? businessNumberLabel,
    String? countryCode,
    String? paymentLinkUrl,
    bool? showBsbAccountOnInvoice,
    bool? showPaymentLinkOnInvoice,
    PreferredUnitSystem? preferredUnitSystem,
    String? logoPath,
    LogoAspectRatio? logoAspectRatio,
    int? billingColour,
    int? photoCacheMaxMb,
    int? paymentTermsInDays,
    String? paymentOptions,
    String? firstname,
    String? surname,
    String? operatingHours,
    String? chatgptAccessToken,
    String? chatgptRefreshToken,
    DateTime? chatgptTokenExpiry,
    String? openaiApiKey,
    String? googleMapsApiKey,
    String? ihserverUrl,
    String? ihserverToken,
    bool? enableIhserverIntegration,
    SmtpProvider? smtpProvider,
    SmtpAuthMode? smtpAuthMode,
    String? smtpHost,
    int? smtpPort,
    String? smtpUsername,
    String? smtpPassword,
    String? smtpFromEmail,
    String? smtpGoogleOAuthClientId,
    bool? smtpUseSsl,
    RichTextRemoved? richTextRemoved,
  }) => System._(
    id: id,
    fromEmail: fromEmail ?? this.fromEmail,
    bsb: bsb ?? this.bsb,
    accountNo: accountNo ?? this.accountNo,
    addressLine1: addressLine1 ?? this.addressLine1,
    addressLine2: addressLine2 ?? this.addressLine2,
    suburb: suburb ?? this.suburb,
    state: state ?? this.state,
    postcode: postcode ?? this.postcode,
    mobileNumber: mobileNumber ?? this.mobileNumber,
    landLine: landLine ?? this.landLine,
    officeNumber: officeNumber ?? this.officeNumber,
    emailAddress: emailAddress ?? this.emailAddress,
    webUrl: webUrl ?? this.webUrl,
    defaultHourlyRate: defaultHourlyRate ?? this.defaultHourlyRate,
    termsUrl: termsUrl ?? this.termsUrl,
    defaultBookingFee: defaultBookingFee ?? this.defaultBookingFee,
    defaultProfitMargin: defaultProfitMargin ?? this.defaultProfitMargin,
    simCardNo: simCardNo ?? this.simCardNo,
    xeroClientId: xeroClientId ?? this.xeroClientId,
    xeroClientSecret: xeroClientSecret ?? this.xeroClientSecret,
    invoiceLineRevenueAccountCode:
        invoiceLineRevenueAccountCode ?? this.invoiceLineRevenueAccountCode,
    invoiceLineInventoryItemCode:
        invoiceLineInventoryItemCode ?? this.invoiceLineInventoryItemCode,
    enableXeroIntegration: enableXeroIntegration ?? this.enableXeroIntegration,
    businessName: businessName ?? this.businessName,
    businessNumber: businessNumber ?? this.businessNumber,
    businessNumberLabel: businessNumberLabel ?? this.businessNumberLabel,
    countryCode: countryCode ?? this.countryCode,
    paymentLinkUrl: paymentLinkUrl ?? this.paymentLinkUrl,
    showBsbAccountOnInvoice:
        showBsbAccountOnInvoice ?? this.showBsbAccountOnInvoice,
    showPaymentLinkOnInvoice:
        showPaymentLinkOnInvoice ?? this.showPaymentLinkOnInvoice,
    preferredUnitSystem: preferredUnitSystem ?? this.preferredUnitSystem,
    logoPath: logoPath ?? this.logoPath,
    logoAspectRatio: logoAspectRatio ?? this.logoAspectRatio,
    billingColour: billingColour ?? this.billingColour,
    photoCacheMaxMb: photoCacheMaxMb ?? this.photoCacheMaxMb,
    paymentTermsInDays: paymentTermsInDays ?? this.paymentTermsInDays,
    paymentOptions: paymentOptions ?? this.paymentOptions,
    firstname: firstname ?? this.firstname,
    surname: surname ?? this.surname,
    richTextRemoved: richTextRemoved ?? this.richTextRemoved,
    operatingHours: operatingHours ?? this.operatingHours,
    chatgptAccessToken: chatgptAccessToken ?? this.chatgptAccessToken,
    chatgptRefreshToken: chatgptRefreshToken ?? this.chatgptRefreshToken,
    chatgptTokenExpiry: chatgptTokenExpiry ?? this.chatgptTokenExpiry,
    openaiApiKey: openaiApiKey ?? this.openaiApiKey,
    googleMapsApiKey: googleMapsApiKey ?? this.googleMapsApiKey,
    ihserverUrl: ihserverUrl ?? this.ihserverUrl,
    ihserverToken: ihserverToken ?? this.ihserverToken,
    enableIhserverIntegration:
        enableIhserverIntegration ?? this.enableIhserverIntegration,
    smtpProvider: smtpProvider ?? this.smtpProvider,
    smtpAuthMode: smtpAuthMode ?? this.smtpAuthMode,
    smtpHost: smtpHost ?? this.smtpHost,
    smtpPort: smtpPort ?? this.smtpPort,
    smtpUsername: smtpUsername ?? this.smtpUsername,
    smtpPassword: smtpPassword ?? this.smtpPassword,
    smtpFromEmail: smtpFromEmail ?? this.smtpFromEmail,
    smtpGoogleOAuthClientId:
        smtpGoogleOAuthClientId ?? this.smtpGoogleOAuthClientId,
    smtpUseSsl: smtpUseSsl ?? this.smtpUseSsl,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory System.fromMap(Map<String, dynamic> map) => System._(
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
    defaultProfitMargin: map['default_profit_margin'] == null
        ? null
        : Percentage.fromInt(
            map['default_profit_margin'] as int,
            decimalDigits: 3,
          ),
    simCardNo: map['sim_card_no'] as int?,
    xeroClientId: map['xero_client_id'] as String?,
    xeroClientSecret: null,
    invoiceLineRevenueAccountCode: map['invoice_line_account_code'] as String?,
    invoiceLineInventoryItemCode: map['invoice_line_item_code'] as String?,
    enableXeroIntegration: (map['enable_xero_integration'] as int? ?? 1) == 1,
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
    logoAspectRatio: LogoAspectRatio.fromName(
      map['logo_aspect_ratio'] as String?,
    ),
    billingColour: map['billing_colour'] as int? ?? 0xFF000000,
    photoCacheMaxMb: map['photo_cache_max_mb'] as int? ?? 100,
    paymentTermsInDays: map['payment_terms_in_days'] as int? ?? 3,
    paymentOptions: map['payment_options'] as String? ?? '',
    firstname: map['firstname'] as String?,
    surname: map['surname'] as String?,
    richTextRemoved: () {
      final v = map['rich_text_removed'];
      if (v is int) {
        return RichTextRemoved.fromOrdinal(v);
      }
      if (v is bool) {
        return v ? RichTextRemoved.job : RichTextRemoved.notYet;
      }
      final parsed = int.tryParse('$v');
      return RichTextRemoved.fromOrdinal(parsed);
    }(),
    operatingHours: map['operating_hours'] as String?,
    chatgptAccessToken: null,
    chatgptRefreshToken: null,
    chatgptTokenExpiry: map['chatgpt_token_expiry'] != null
        ? DateTime.parse(map['chatgpt_token_expiry'] as String)
        : null,
    openaiApiKey: null,
    googleMapsApiKey: null,
    ihserverUrl: map['ihserver_url'] as String?,
    ihserverToken: null,
    enableIhserverIntegration:
        (map['enable_ihserver_integration'] as int? ?? 0) == 1,
    smtpProvider: SmtpProvider.fromName(map['smtp_provider'] as String?),
    smtpAuthMode: SmtpAuthMode.fromName(map['smtp_auth_mode'] as String?),
    smtpHost: map['smtp_host'] as String?,
    smtpPort: map['smtp_port'] as int? ?? 587,
    smtpUsername: map['smtp_username'] as String?,
    smtpPassword: null,
    smtpFromEmail: map['smtp_from_email'] as String?,
    smtpGoogleOAuthClientId: map['smtp_google_oauth_client_id'] as String?,
    smtpUseSsl: (map['smtp_use_ssl'] as int? ?? 0) == 1,
    createdDate:
        DateTime.tryParse(map['created_date'] as String? ?? '') ??
        DateTime.now(),
    modifiedDate:
        DateTime.tryParse(map['modified_date'] as String? ?? '') ??
        DateTime.now(),
  );

  void setOperatingHours(OperatingHours schedule) {
    operatingHours = schedule.toJson();
  }

  OperatingHours getOperatingHours() => OperatingHours.fromJson(operatingHours);

  String? get bestPhone {
    if (Strings.isNotBlank(mobileNumber)) {
      return mobileNumber;
    } else if (Strings.isNotBlank(landLine)) {
      return landLine;
    } else {
      return officeNumber;
    }
  }

  String get address =>
      joinAddressParts([addressLine1, addressLine2, suburb, state, postcode]);

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
    'default_profit_margin': defaultProfitMargin
        ?.copyWith(decimalDigits: 3)
        .minorUnits
        .toInt(),
    'sim_card_no': simCardNo,
    'xero_client_id': xeroClientId,
    'invoice_line_account_code': invoiceLineRevenueAccountCode,
    'invoice_line_item_code': invoiceLineInventoryItemCode,
    'enable_xero_integration': enableXeroIntegration ? 1 : 0,
    'business_name': businessName,
    'business_number': businessNumber,
    'business_number_label': businessNumberLabel,
    'country_code': countryCode,
    'payment_link_url': paymentLinkUrl,
    'show_bsb_account_on_invoice': showBsbAccountOnInvoice ?? true ? 1 : 0,
    'show_payment_link_on_invoice': showPaymentLinkOnInvoice ?? true ? 1 : 0,
    'use_metric_units': preferredUnitSystem == PreferredUnitSystem.metric
        ? 1
        : 0,
    'logo_path': logoPath,
    'logo_aspect_ratio': logoAspectRatio.name,
    'billing_colour': billingColour,
    'photo_cache_max_mb': photoCacheMaxMb,
    'payment_terms_in_days': paymentTermsInDays,
    'payment_options': paymentOptions,
    'firstname': firstname,
    'surname': surname,
    'rich_text_removed': richTextRemoved.ordinal,
    'operating_hours': operatingHours,
    'chatgpt_token_expiry': chatgptTokenExpiry?.toIso8601String(),
    'ihserver_url': ihserverUrl,
    'enable_ihserver_integration': enableIhserverIntegration ? 1 : 0,
    'smtp_provider': smtpProvider.name,
    'smtp_auth_mode': smtpAuthMode.name,
    'smtp_host': smtpHost,
    'smtp_port': smtpPort,
    'smtp_username': smtpUsername,
    'smtp_from_email': smtpFromEmail,
    'smtp_google_oauth_client_id': smtpGoogleOAuthClientId,
    'smtp_use_ssl': smtpUseSsl ? 1 : 0,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };

  bool isExternalAccountingEnabled() =>
      enableXeroIntegration && Strings.isNotBlank(xeroClientId);
}

/// An immutable snapshot of non-secret system configuration.
///
/// Integration credentials are deliberately absent. Retrieve them through the
/// integration-specific methods on `DaoSystem`.
@immutable
class SystemConfiguration {
  final System _system;

  SystemConfiguration._(System system)
    : _system = System.fromMap(system.toMap());

  factory SystemConfiguration.fromSystem(System system) =>
      SystemConfiguration._(system);

  int get id => _system.id;
  DateTime get createdDate => _system.createdDate;
  DateTime get modifiedDate => _system.modifiedDate;
  String? get fromEmail => _system.fromEmail;
  String? get bsb => _system.bsb;
  String? get accountNo => _system.accountNo;
  String? get addressLine1 => _system.addressLine1;
  String? get addressLine2 => _system.addressLine2;
  String? get suburb => _system.suburb;
  String? get state => _system.state;
  String? get postcode => _system.postcode;
  String? get mobileNumber => _system.mobileNumber;
  String? get landLine => _system.landLine;
  String? get officeNumber => _system.officeNumber;
  String? get emailAddress => _system.emailAddress;
  String? get webUrl => _system.webUrl;
  Money? get defaultHourlyRate => _system.defaultHourlyRate;
  String? get termsUrl => _system.termsUrl;
  Money? get defaultBookingFee => _system.defaultBookingFee;
  Percentage? get defaultProfitMargin => _system.defaultProfitMargin;
  int? get simCardNo => _system.simCardNo;
  String? get xeroClientId => _system.xeroClientId;
  String? get invoiceLineRevenueAccountCode =>
      _system.invoiceLineRevenueAccountCode;
  String? get invoiceLineInventoryItemCode =>
      _system.invoiceLineInventoryItemCode;
  bool get enableXeroIntegration => _system.enableXeroIntegration;
  String? get businessName => _system.businessName;
  String? get businessNumber => _system.businessNumber;
  String? get businessNumberLabel => _system.businessNumberLabel;
  String? get countryCode => _system.countryCode;
  String? get paymentLinkUrl => _system.paymentLinkUrl;
  bool? get showBsbAccountOnInvoice => _system.showBsbAccountOnInvoice;
  bool? get showPaymentLinkOnInvoice => _system.showPaymentLinkOnInvoice;
  PreferredUnitSystem get preferredUnitSystem => _system.preferredUnitSystem;
  String get logoPath => _system.logoPath;
  LogoAspectRatio get logoAspectRatio => _system.logoAspectRatio;
  int get billingColour => _system.billingColour;
  int get photoCacheMaxMb => _system.photoCacheMaxMb;
  int get paymentTermsInDays => _system.paymentTermsInDays;
  String get paymentOptions => _system.paymentOptions;
  String? get firstname => _system.firstname;
  String? get surname => _system.surname;
  String? get operatingHours => _system.operatingHours;
  DateTime? get chatgptTokenExpiry => _system.chatgptTokenExpiry;
  String? get ihserverUrl => _system.ihserverUrl;
  bool get enableIhserverIntegration => _system.enableIhserverIntegration;
  SmtpProvider get smtpProvider => _system.smtpProvider;
  SmtpAuthMode get smtpAuthMode => _system.smtpAuthMode;
  String? get smtpHost => _system.smtpHost;
  int get smtpPort => _system.smtpPort;
  String? get smtpUsername => _system.smtpUsername;
  String? get smtpFromEmail => _system.smtpFromEmail;
  String? get smtpGoogleOAuthClientId => _system.smtpGoogleOAuthClientId;
  bool get smtpUseSsl => _system.smtpUseSsl;
  RichTextRemoved get richTextRemoved => _system.richTextRemoved;

  String? get bestPhone => _system.bestPhone;
  String get address => _system.address;

  OperatingHours getOperatingHours() => _system.getOperatingHours();

  bool isExternalAccountingEnabled() => _system.isExternalAccountingEnabled();
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

  /// Looks up the appropriate DayName based on the enum name string
  /// (e.g., "mon").
  /// Throws a StateError if the provided dayStr doesn't match any known enum.
  static DayName fromJson(String dayStr) =>
      DayName.values.firstWhere((e) => e.name == dayStr);

  static DayName fromIndex(int index) => DayName.values[index];

  static DayName fromDate(LocalDate when) => DayName.fromWeekDay(when.weekday);

  /// From the 1 based [dayOfWeek] where Monday is 1.
  static DayName fromWeekDay(int dayOfWeek) => DayName.values[dayOfWeek - 1];
}

// {
// HMBToast.info(
//   'Unable to extract any customer details from the message.
//You can copy and paste the details manually.',
// );

import 'dart:ui';

import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_site.dart';
import '../../../dao/dao_system.dart';
import '../../../entity/site.dart';
import 'parse_address.dart';

/// --------------------------
/// ParsedCustomer
/// --------------------------
class ParsedCustomer {
  // ---------- private helpers ----------
  static const _emailRe =
      r'''(?:[a-z0-9!#\$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#\$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])''';

  // ---------- public fields ----------
  String customerName;
  String companyName;
  String email;
  String mobile;
  String firstname;
  String surname;
  ParsedAddress address;

  ParsedCustomer({
    required this.customerName,
    required this.companyName,
    required this.email,
    required this.firstname,
    required this.surname,
    required this.mobile,
    required this.address,
  });

  // ---------- factory parser ----------
  static Future<ParsedCustomer> parse(String text) async {
    final system = await DaoSystem().get();
    final recipientFirstName = system.firstname ?? '';
    final recipientSurname = system.surname ?? '';

    // 0️⃣  SCRUB recipient’s name tokens first  –––––––––––––––––––––––––
    final tokens = text.split(RegExp(r'\s+')).map((token) {
      final clean = token.replaceAll(RegExp(r'[^\w]'), ''); // strip punctuation
      if (clean.equalsIgnoreCase(recipientFirstName) ||
          clean.equalsIgnoreCase(recipientSurname)) {
        return '*' * token.length; // preserve spacing
      }
      return token;
    }).toList();
    final scrubbedText = tokens.join(' ');

    // 1️⃣  Extract core items (email, phone, address)
    final email = _parseEmail(scrubbedText);
    final mobile = _parsePhone(scrubbedText);
    final parsedAddress = ParsedAddress.parse(scrubbedText);
    final address = await _mergeWithKnownSiteAddress(
      scrubbedText,
      parsedAddress,
    );

    // 2️⃣  Remove street + city tokens from the text before name search
    var scrubbed = scrubbedText;
    if (address.street.isNotEmpty) {
      scrubbed = scrubbed.replaceAll(
        RegExp(RegExp.escape(address.street), caseSensitive: false),
        '*' * address.street.length,
      );
    }
    if (address.city.isNotEmpty) {
      scrubbed = scrubbed.replaceAll(
        RegExp(RegExp.escape(address.city), caseSensitive: false),
        '*' * address.city.length,
      );
    }

    // 3️⃣  Find a name that isn’t the recipient’s
    final nameRegex = RegExp(r'\b([A-Z][a-z]+)\s+([A-Z][a-z]+)\b');

    var firstName = '';
    var lastName = '';

    final matches = nameRegex.allMatches(scrubbed).toList().reversed;

    for (final match in matches) {
      firstName = match.group(1) ?? '';
      lastName = match.group(2) ?? '';
      break;
    }

    final customerName = '$firstName $lastName'.trim();

    return ParsedCustomer(
      customerName: customerName,
      companyName: '',
      email: email,
      mobile: mobile,
      firstname: firstName,
      surname: lastName,
      address: address,
    );
  }

  bool isEmpty() =>
      Strings.isBlank(firstname) &&
      Strings.isBlank(surname) &&
      Strings.isBlank(email) &&
      Strings.isBlank(mobile) &&
      Strings.isBlank(customerName) &&
      Strings.isBlank(companyName) &&
      address.isEmpty();

  static String _parseEmail(String? text) =>
      RegExp(_emailRe).firstMatch(text ?? '')?.group(0) ?? '';

  static String _parsePhone(String? input) {
    if (Strings.isBlank(input)) {
      return '';
    }

    final util = PhoneNumberUtil.instance;
    final region = _deviceRegion() ?? 'AU';

    for (final len in [
      Leniency.exactGrouping,
      Leniency.strictGrouping,
      Leniency.valid,
      Leniency.possible,
    ]) {
      final matches = util.findNumbers(input!, region, len, Int64(20));
      if (matches.isNotEmpty) {
        return _formatPhone(matches.first.number, region);
      }
    }
    return '';
  }

  static String? _deviceRegion() =>
      PlatformDispatcher.instance.locale.countryCode;

  static String _formatPhone(PhoneNumber phone, String defaultRegion) {
    final util = PhoneNumberUtil.instance;
    final isLocal =
        phone.countryCode == util.getCountryCodeForRegion(defaultRegion);
    final fmt = isLocal
        ? PhoneNumberFormat.national
        : PhoneNumberFormat.international;
    return util.format(phone, fmt);
  }

  static Future<ParsedAddress> _mergeWithKnownSiteAddress(
    String sourceText,
    ParsedAddress parsedAddress,
  ) async {
    final matchedAddress = await _matchKnownSiteAddress(sourceText);
    if (matchedAddress == null) {
      return parsedAddress;
    }

    return ParsedAddress(
      street: parsedAddress.street.isNotEmpty
          ? parsedAddress.street
          : matchedAddress.street,
      city: parsedAddress.city.isNotEmpty
          ? parsedAddress.city
          : matchedAddress.city,
      state: parsedAddress.state.isNotEmpty
          ? parsedAddress.state
          : matchedAddress.state,
      postalCode: parsedAddress.postalCode.isNotEmpty
          ? parsedAddress.postalCode
          : matchedAddress.postalCode,
    );
  }

  static Future<ParsedAddress?> _matchKnownSiteAddress(
    String sourceText,
  ) async {
    final text = _normalizeForMatch(sourceText);
    if (text.isEmpty) {
      return null;
    }

    final sites = await DaoSite().getAll();
    Site? best;
    var bestScore = 0;

    for (final site in sites) {
      final suburb = _normalizeForMatch(site.suburb);
      final streetName = _normalizeStreetName(site.addressLine1);
      if (suburb.isEmpty || streetName.isEmpty) {
        continue;
      }

      final suburbMatched = _containsWholePhrase(text, suburb);
      final streetMatched = _containsWholePhrase(text, streetName);
      if (!suburbMatched || !streetMatched) {
        continue;
      }

      var score = 8;
      final streetNo = _extractStreetNumber(site.addressLine1);
      if (streetNo.isNotEmpty && _containsWholePhrase(text, streetNo)) {
        score += 2;
      }
      if (site.postcode.isNotEmpty &&
          _containsWholePhrase(text, _normalizeForMatch(site.postcode))) {
        score += 1;
      }

      if (score > bestScore) {
        best = site;
        bestScore = score;
      }
    }

    if (best == null) {
      return null;
    }

    return ParsedAddress(
      street: best.addressLine1.trim(),
      city: best.suburb.trim(),
      state: best.state.trim(),
      postalCode: best.postcode.trim(),
    );
  }

  static String _normalizeStreetName(String addressLine1) {
    final normalized = _normalizeForMatch(addressLine1);
    if (normalized.isEmpty) {
      return '';
    }
    final parts = normalized
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
    while (parts.isNotEmpty && _isNumberToken(parts.first)) {
      parts.removeAt(0);
    }
    return parts.join(' ');
  }

  static String _extractStreetNumber(String addressLine1) {
    final normalized = _normalizeForMatch(addressLine1);
    final parts = normalized
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '';
    }
    return _isNumberToken(parts.first) ? parts.first : '';
  }

  static bool _isNumberToken(String token) =>
      RegExp(r'^\d+[a-z]?$').hasMatch(token) ||
      RegExp(r'^\d+/\d+[a-z]?$').hasMatch(token);

  static String _normalizeForMatch(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9/\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _containsWholePhrase(String text, String phrase) {
    if (phrase.isEmpty) {
      return false;
    }

    final escaped = phrase
        .split(' ')
        .where((token) => token.isNotEmpty)
        .map(RegExp.escape)
        .join(r'\s+');
    if (escaped.isEmpty) {
      return false;
    }
    final pattern = RegExp(r'\b' + escaped + r'\b');
    return pattern.hasMatch(text);
  }
}

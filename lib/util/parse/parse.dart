import 'dart:ui';

import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'package:strings/strings.dart';

const emailRegEx =
    r'''(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])''';
String parseEmail(String? text) {
  text ??= '';

  final emailMatch = RegExp(emailRegEx).firstMatch(text);
  final email = emailMatch?.group(0) ?? '';
  return email;
}

bool isValidEmail(String value) => RegExp(emailRegEx).hasMatch(value);

/// Returns the first phone number found in [input].
/// Uses the devices region to detect region specific
/// phone number formats.
String parsePhone(String? input) {
  if (Strings.isBlank(input)) {
    return '';
  }
  final util = PhoneNumberUtil.instance;

  final region = getDeviceRegion() ?? 'AU';
  var matches = util.findNumbers(
    input!,
    region,
    Leniency.exactGrouping,
    Int64(20),
  );

  if (matches.isNotEmpty) {
    return formatForDisplay(phone: matches.first.number, defaultRegion: region);
  }

  matches = util.findNumbers(input, region, Leniency.strictGrouping, Int64(20));

  if (matches.isNotEmpty) {
    return formatForDisplay(phone: matches.first.number, defaultRegion: region);
  }

  matches = util.findNumbers(input, region, Leniency.valid, Int64(20));

  if (matches.isNotEmpty) {
    return formatForDisplay(phone: matches.first.number, defaultRegion: region);
  }

  matches = util.findNumbers(input, region, Leniency.possible, Int64(20));

  if (matches.isNotEmpty) {
    return formatForDisplay(phone: matches.first.number, defaultRegion: region);
  }
  return '';
}

String? getDeviceRegion() {
  // Works on Flutter 3.13 +
  final locale = PlatformDispatcher.instance.locale; // e.g. en_AU
  return locale.countryCode; // -> "AU"
}

String formatForDisplay({
  required PhoneNumber phone,
  required String defaultRegion, // e.g. "AU"
}) {
  final util = PhoneNumberUtil.instance;

  // Is the parsed number actually from the default region?
  final isLocal =
      phone.countryCode == util.getCountryCodeForRegion(defaultRegion);

  // Choose format:
  //  • Local region  →  use NATIONAL (shortest valid form)
  //  • Foreign       →  use INTERNATIONAL (with country code)
  final format = isLocal
      ? PhoneNumberFormat.national
      : PhoneNumberFormat.international;

  return util.format(phone, format);
}

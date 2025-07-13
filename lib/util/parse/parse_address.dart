// parsed_customer.dart
// --------------------------------------------------------------
// One file containing both ParsedCustomer and ParsedAddress.
// --------------------------------------------------------------

import 'package:strings/strings.dart';

/// --------------------------
/// ParsedAddress
/// --------------------------
class ParsedAddress {
  ParsedAddress({
    this.street = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
  });

  factory ParsedAddress.parse(String text) =>
      // _parseAddressEsri(text.replaceAll('\n', '').replaceAll('\r\n', ''));
      _parseAddressEsri(text);
  // ---------- public fields ----------
  String street;
  String city;
  String state;
  String postalCode;

  bool isEmpty() =>
      Strings.isBlank(street) &&
      Strings.isBlank(city) &&
      Strings.isBlank(state) &&
      Strings.isBlank(postalCode);

  // ---------- implementation ----------
  static List<ParsedAddress> parseAddressList(String multilineInput) {
    final lines = multilineInput
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return lines
        .map(_parseAddressEsri)
        .where((addr) => !addr.isEmpty())
        .toList();
  }

  static ParsedAddress _parseAddressEsri(String input) {
    final addr = ParsedAddress();
    final tokens = input.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty) {
      return addr;
    }

    // 1️⃣  Find first token that looks like a unit or street number.
    for (var i = 0; i < tokens.length; i++) {
      final anchor = tokens[i];

      // Skip if token contains any disallowed characters
      if (RegExp(r'''[(){}\[\]<>:;"\'!@#\$%^&*+=?~]''').hasMatch(anchor)) {
        continue;
      }

      if (!RegExp(r'^\d+[A-Za-z]?(/\d+)?$').hasMatch(anchor)) {
        continue;
      }

      // 2️⃣  Find a known street suffix after the anchor within 3 tokens.
      var suffixIndex = -1;
      for (var j = i + 1; j <= i + 3 && j < tokens.length; j++) {
        // Skip if token has disallowed punctuation
        if (RegExp(r'''[(){}\[\]<>:;"\'!@#\$%^&*+=?~]''').hasMatch(tokens[j])) {
          continue;
        }

        final word = tokens[j].toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
        if (_streetSuffixes.contains(word)) {
          suffixIndex = j;
          break;
        }
      }
      if (suffixIndex == -1) {
        continue; // no suffix → keep searching
      }

      // 3️⃣  Street = anchor … suffix,  City = remaining tokens.
      final streetTokens = tokens.sublist(i, suffixIndex + 1);
      final cityTokens = tokens.sublist(suffixIndex + 1);

      final cleanCityTokens = <String>[];
      for (final token in cityTokens) {
        if (cleanCityTokens.length >= 3) {
          break;
        }

        // Reject token if it has disallowed punctuation
        if (RegExp(r'''[(){}\[\]<>:;"'!@#\$%^&*+=?~]''').hasMatch(token)) {
          break;
        }

        // Reject token if it doesn't start with an uppercase letter
        if (!RegExp('^[A-Z]').hasMatch(token)) {
          break;
        }

        cleanCityTokens.add(token);
      }

      addr
        ..street = streetTokens.map(_stripTrailingPunctuation).join(' ')
        ..city = cleanCityTokens.map(_stripTrailingPunctuation).join(' ')
        ..state = ''
        ..postalCode = '';
      return addr;
    }

    // No valid street pattern found
    return addr;
  }

  // util helpers
  static String _stripTrailingPunctuation(String s) =>
      s.trim().replaceAll(RegExp(r'[.,;:!]+$'), '');

  static List<String> _truncateWords(String s, int max) =>
      s.trim().split(RegExp(r'\s+')).take(max).toList();

  static const _streetSuffixes = {
    'st',
    'street',
    'rd',
    'road',
    'ave',
    'avenue',
    'blvd',
    'boulevard',
    'dr',
    'drive',
    'ln',
    'lane',
    'ct',
    'court',
    'cr',
    'crescent',
    'pl',
    'place',
    'sq',
    'square',
    'pde',
    'parade',
    'tce',
    'terrace',
    'ter',
    'hwy',
    'highway',
    'way',
    'gr',
    'grove',
    'walk',
    'cct',
    'circuit',
    'row',
    'trl',
    'trail',
    'bvd',
    'cl',
    'close',
    'mews',
    'esplanade',
    'bypass',
    'view',
    'outlook',
    'bend',
    'loop',
    'retreat',
  };
}

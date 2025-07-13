import 'package:strings/strings.dart';

class ParsedAddress {
  ParsedAddress({
    this.street = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
  });

  factory ParsedAddress.parse(String text) =>
      parseAddressList(text).firstOrNull ?? ParsedAddress();

  static List<ParsedAddress> parseAddressList(String multilineInput) {
    final lines = multilineInput
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // only return non-empty addresses.
    return lines
        .map(parseAddressEsri)
        .where((address) => !address.isEmpty())
        .toList();
  }

  /// Attempt to extract address components from a string formatted like an Esri address.
  /// https://stackoverflow.com/questions/11160192/how-to-parse-freeform-street-postal-address-out-of-text-and-into-components
  static ParsedAddress parseAddressEsri(String input) {
    final address = ParsedAddress();
    final tokens = input.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty) {
      return address;
    }

    for (var i = 0; i < tokens.length; i++) {
      final anchor = tokens[i];
      if (!RegExp(r'^\d+[A-Za-z]?(/\d+)?$').hasMatch(anchor)) {
        continue;
      }

      // Try to find the street suffix in the tokens following the anchor
      var suffixIndex = -1;
      for (var j = i + 1; j < tokens.length; j++) {
        final word = tokens[j].toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
        if (streetSuffixes.contains(word)) {
          suffixIndex = j;
          break;
        }
      }

      // If no suffix found, this is not a valid street → continue searching
      if (suffixIndex == -1) {
        continue;
      }

      // Valid street found → extract street and city
      final streetTokens = tokens.sublist(i, suffixIndex + 1);
      final cityTokens = tokens.sublist(suffixIndex + 1);

      address
        ..street = _stripTrailingPunctuation(streetTokens.join(' '))
        ..city = _stripTrailingPunctuation(
          _truncateWords(cityTokens.join(' '), 3).join(' '),
        )
        ..state = ''
        ..postalCode = '';

      return address;
    }

    // No valid street pattern found
    return address;
  }

  // Limit city and state to at most 3 words each
  static List<String> _truncateWords(String input, int maxWords) {
    final words = input.trim().split(RegExp(r'\s+'));
    return words.take(maxWords).toList();
  }

  String street;
  String city;
  String state;
  String postalCode;

  bool isEmpty() =>
      Strings.isBlank(street) &&
      Strings.isBlank(city) &&
      Strings.isBlank(state) &&
      Strings.isBlank(postalCode);
  // Remove trailing punctuation
  static String _stripTrailingPunctuation(String input) =>
      input.trim().replaceAll(RegExp(r'[.,;:!]+$'), '');
}

const streetSuffixes = {
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

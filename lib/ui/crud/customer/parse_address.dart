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

    // Tokenize by whitespace (retain commas)
    final tokens = input.trim().split(RegExp(r'\s+'));
    final workingTokens = List<String>.from(tokens);
    if (workingTokens.isEmpty) {
      return address;
    }

    String? lastToken = workingTokens.removeLast();

    bool isNumeric(String s) => int.tryParse(s) != null;

    // Check if last token is a postal code
    if (isNumeric(lastToken) ||
        RegExp(r'^(\d{5}-\d{4}|\d{4})$').hasMatch(lastToken)) {
      address.postalCode = lastToken;
      if (workingTokens.isEmpty) {
        return address;
      }
      lastToken = workingTokens.removeLast();
    }

    if (!isNumeric(lastToken)) {
      if (address.postalCode.isNotEmpty && lastToken.length == 2) {
        // Likely state code
        address.state = lastToken;
        if (workingTokens.isNotEmpty) {
          lastToken = workingTokens.removeLast();
        }
      }

      if (address.state.isEmpty) {
        // Could be full state name
        final stateNameParts = <String>[
          if (lastToken.endsWith(','))
            lastToken.substring(0, lastToken.length - 1)
          else
            lastToken,
        ];

        while (true) {
          if (workingTokens.isEmpty) {
            break;
          }
          lastToken = workingTokens.removeLast();
          if (lastToken.endsWith(',')) {
            workingTokens.add(lastToken); // push back
            break;
          } else {
            stateNameParts.insert(0, lastToken);
          }
        }
        address.state = stateNameParts.join(' ');
        if (workingTokens.isNotEmpty) {
          lastToken = workingTokens.removeLast();
        }
      }
    }

    if (lastToken != null) {
      if (address.state.isNotEmpty) {
        final cityNameParts = <String>[
          if (lastToken.endsWith(','))
            lastToken.substring(0, lastToken.length - 1)
          else
            lastToken,
        ];

        final streetNameParts = <String>[];

        while (true) {
          if (workingTokens.isEmpty) {
            break;
          }
          lastToken = workingTokens.removeLast();
          if (lastToken.endsWith(',')) {
            final tokenWithoutComma = lastToken.substring(
              0,
              lastToken.length - 1,
            );
            workingTokens.add(tokenWithoutComma);
            streetNameParts.addAll(workingTokens);
            break;
          } else {
            cityNameParts.insert(0, lastToken);
          }
        }
        address
          ..city = cityNameParts.join(' ')
          ..street = streetNameParts.join(' ');
      } else {
        // No state means no city, just street
        workingTokens.add(lastToken);
        address.street = workingTokens.join(' ');
      }
    }

    // Shift fallback
    if (address.city.isEmpty && address.state.isNotEmpty) {
      address
        ..city = address.state
        ..state = '';
    }
    if (address.street.isEmpty) {
      address
        ..street = address.city
        ..city = '';
    }

    return address;
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
}

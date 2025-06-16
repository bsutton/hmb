extension UriEx on Uri {
  /// Returns true if [input] is a valid absolute HTTP or HTTPS URL.
  static bool isValid(String? input) {
    if (input == null || input.trim().isEmpty) {
      return false;
    }

    try {
      final uri = Uri.parse(input.trim());
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

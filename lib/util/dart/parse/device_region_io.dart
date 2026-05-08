import 'dart:io';

String? deviceRegion() {
  final locale = Platform.localeName;
  if (locale.isEmpty) {
    return null;
  }

  final parts = locale.split(RegExp('[-_]'));
  if (parts.length < 2 || parts[1].isEmpty) {
    return null;
  }

  final countryCode = parts[1].split('.').first.toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)) {
    return null;
  }

  return countryCode;
}

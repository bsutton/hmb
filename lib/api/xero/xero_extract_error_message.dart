// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

/// Given an exception whose message may include a Xero error-JSON blob,
/// returns a user-friendly string for display.
String extractXeroErrorMessage(String body) {
  final jsonStart = body.indexOf('{');
  if (jsonStart < 0) {
    // No JSON at all
    return body;
  }

  final jsonPart = body.substring(jsonStart);
  Map<String, dynamic> payload;
  try {
    payload = jsonDecode(jsonPart) as Map<String, dynamic>;
  } catch (_) {
    // Couldn't parse JSON
    return body;
  }

  final type = payload['Type'] as String? ?? 'Error';
  final message = payload['Message'] as String? ?? 'An error occurred';

  // If it's a validation exception, dig deeper for all the field errors:
  if (type == 'ValidationException') {
    final errors = <String>[];

    // Elements[].ValidationErrors
    for (final element in (payload['Elements'] as List<dynamic>? ?? [])) {
      for (final ve in (element['ValidationErrors'] as List<dynamic>? ?? [])) {
        errors.add(ve['Message'] as String);
      }
      // LineItems[].ValidationErrors
      for (final line in (element['LineItems'] as List<dynamic>? ?? [])) {
        for (final ve in (line['ValidationErrors'] as List<dynamic>? ?? [])) {
          errors.add(ve['Message'] as String);
        }
      }
    }

    if (errors.isNotEmpty) {
      // Remove duplicates and join
      return errors.toSet().join('; ');
    }
    // Fallback to the generic message
  }

  // Non-validation or no detailed errors: just "Type: Message"
  return '$type: $message';
}

/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'package:strings/strings.dart';

String cleanAddressPart(String? value) {
  var cleaned = (value ?? '').trim();
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
  cleaned = cleaned.replaceAll(RegExp(r'\s*,\s*'), ', ');
  cleaned = cleaned.replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');
  return cleaned;
}

String joinAddressParts(Iterable<String?> parts) => Strings.join(
  parts.map(cleanAddressPart).toList(),
  separator: ', ',
  excludeEmpty: true,
);

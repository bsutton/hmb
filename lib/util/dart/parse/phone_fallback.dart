String parseAustralianMobileFallback(String input) {
  final match = RegExp(r'\b(04(?:[\s-]?\d){8})\b').firstMatch(input);
  if (match == null) {
    return '';
  }

  return match.group(1)!.replaceAll(RegExp(r'\D'), '');
}

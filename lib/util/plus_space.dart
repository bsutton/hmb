/// If [label] is non null then we add a space before it.
/// otherwise we return an empty string.
String plusSpace(String? label) {
  if (label != null) {
    return '$label ';
  }

  return '';
}

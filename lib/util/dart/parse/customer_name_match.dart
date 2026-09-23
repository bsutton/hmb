/// Ranks local name candidates for review, never for automatic assignment.
double customerNameSimilarity(String source, String candidate) {
  String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final left = normalize(source);
  final right = normalize(candidate);
  if (left.isEmpty || right.isEmpty) {
    return 0;
  }
  var previous = List.generate(right.length + 1, (index) => index);
  for (var row = 1; row <= left.length; row++) {
    final current = <int>[row];
    for (var column = 1; column <= right.length; column++) {
      final insert = current[column - 1] + 1;
      final delete = previous[column] + 1;
      final substitute =
          previous[column - 1] + (left[row - 1] == right[column - 1] ? 0 : 1);
      current.add([insert, delete, substitute].reduce((a, b) => a < b ? a : b));
    }
    previous = current;
  }
  final length = left.length > right.length ? left.length : right.length;
  return 1 - previous.last / length;
}

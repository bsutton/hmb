/// Used to import nothing when doing a conditional import.
library;

/// Dummy script for non-windows platforms.
class DartScript {
  // ignore: prefer_constructors_over_static_methods
  static DartScript self() => DartScript();

  String get pathToScript => '';
}

// ignore: dangling_library_doc_comments
import 'dart:io';

/// Used to import nothing when doing a conditioal import.

/// Dummy script for non-windows platforms.
class DartScript {
  // ignore: prefer_constructors_over_static_methods
  static DartScript self() => DartScript();

  String get pathToScript => Platform.script.path;
}

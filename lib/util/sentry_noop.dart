/// Used to noop calls to sentry on non-supported platforms.
///
library;

// ignore: avoid_classes_with_only_static_members
class Sentry {
  static Future<void> captureException(
    Object e, {
    StackTrace? stackTrace,
  }) async {}
}

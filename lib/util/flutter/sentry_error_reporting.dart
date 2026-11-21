import 'package:sentry_flutter/sentry_flutter.dart';

import '../dart/sentry_error_reporting.dart';

/// Disable Flutter and native performance collection without disabling errors.
void configureFlutterSentryErrorReporting(SentryFlutterOptions options) {
  configureSentryErrorReporting(options);
  options
    ..enableAutoPerformanceTracing = false
    ..enableFramesTracking = false
    ..enableNativeTraceSync = false
    ..enableAutoSessionTracking = false;
  options.replay
    ..sessionSampleRate = 0
    ..onErrorSampleRate = 0;
}

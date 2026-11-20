import 'package:sentry/sentry.dart';

/// Keep exception and crash reporting without performance telemetry.
void configureSentryErrorReporting(SentryOptions options) {
  options
    ..tracesSampleRate = null
    ..tracesSampler = null
    ..beforeSendLog = _dropTelemetry
    ..beforeSendMetric = _dropTelemetry;
}

T? _dropTelemetry<T>(T item, Hint hint) => null;

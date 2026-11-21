import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/util/dart/sentry_error_reporting.dart';
import 'package:hmb/util/flutter/sentry_error_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('backup isolates retain error sampling without traces', () {
    final options = SentryOptions()
      ..tracesSampleRate = 1.0
      ..tracesSampler = (_) => 1.0;
    configureSentryErrorReporting(options);

    expect(options.isTracingEnabled(), isFalse);
    expect(options.sampleRate, anyOf(isNull, 1.0));
    expect(options.beforeSend, isNull);
    expect(options.beforeSendLog, isNotNull);
    expect(options.beforeSendMetric, isNotNull);
  });

  test('Flutter retains errors but disables tracing and replay', () {
    final options = SentryFlutterOptions()..tracesSampleRate = 1.0;
    options.replay
      ..sessionSampleRate = 1.0
      ..onErrorSampleRate = 1.0;
    configureFlutterSentryErrorReporting(options);

    expect(options.isTracingEnabled(), isFalse);
    expect(options.sampleRate, anyOf(isNull, 1.0));
    expect(options.beforeSend, isNull);
    expect(options.enableAutoPerformanceTracing, isFalse);
    expect(options.enableFramesTracking, isFalse);
    expect(options.enableNativeTraceSync, isFalse);
    expect(options.enableAutoSessionTracking, isFalse);
    expect(options.replay.sessionSampleRate, 0);
    expect(options.replay.onErrorSampleRate, 0);
  });
}

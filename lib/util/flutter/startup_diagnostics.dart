import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sqflite_common/sqlite_api.dart';

typedef StartupReporter =
    Future<void> Function(
      String phase,
      String outcome,
      Duration elapsed,
      StackTrace stack,
      String? errorType,
    );

/// Observes startup without cancelling an in-flight migration or waiting for
/// telemetry delivery. Reports contain phase names, timings and error types.
class StartupDiagnostics {
  final Duration stallThreshold;
  final StartupReporter _report;

  StartupDiagnostics({
    this.stallThreshold = const Duration(seconds: 30),
    StartupReporter? report,
  }) : _report = report ?? _reportToSentry;

  Future<T> run<T>(String phase, FutureOr<T> Function() action) async {
    final elapsed = Stopwatch()..start();
    final startedAt = StackTrace.current;
    _breadcrumb(phase, 'started', Duration.zero);
    final timer = Timer(stallThreshold, () {
      _breadcrumb(phase, 'stalled', elapsed.elapsed);
      _send(phase, 'stalled', elapsed.elapsed, startedAt, null);
    });
    try {
      final result = await action();
      _breadcrumb(phase, 'completed', elapsed.elapsed);
      return result;
    } catch (error, stack) {
      _breadcrumb(phase, 'failed', elapsed.elapsed);
      final type = error is DatabaseException
          ? '${error.runtimeType} (SQLite ${error.getResultCode()})'
          : '${error.runtimeType}';
      _send(phase, 'failed', elapsed.elapsed, stack, type);
      rethrow;
    } finally {
      timer.cancel();
      elapsed.stop();
    }
  }

  void _send(
    String phase,
    String outcome,
    Duration elapsed,
    StackTrace stack,
    String? errorType,
  ) {
    unawaited(
      Future<void>.sync(
        () => _report(phase, outcome, elapsed, stack, errorType),
      ).catchError((Object _) {
        print('Startup diagnostic delivery failed.');
      }),
    );
  }

  void _breadcrumb(String phase, String outcome, Duration elapsed) {
    // Sentry redirects debugPrint to breadcrumbs in release builds. Keep this
    // console message available in Android logcat as well.
    print('Startup phase $outcome: $phase (${elapsed.inMilliseconds} ms)');
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'app.startup',
          message: '$phase: $outcome',
          data: {'elapsed_ms': elapsed.inMilliseconds},
        ),
      ).catchError((Object _) {}),
    );
  }

  static Future<void> _reportToSentry(
    String phase,
    String outcome,
    Duration elapsed,
    StackTrace stack,
    String? errorType,
  ) async {
    await Sentry.captureException(
      StateError('Startup $outcome during $phase'),
      stackTrace: stack,
      withScope: (scope) async {
        await scope.setTag('startup.phase', phase);
        await scope.setTag('startup.outcome', outcome);
        await scope.setContexts('startup', {
          'phase': phase,
          'outcome': outcome,
          'elapsed_ms': elapsed.inMilliseconds,
          'error_type': ?errorType,
        });
      },
    );
  }
}

import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';

import '../database/factory/flutter_database_factory.dart';
import '../database/management/database_helper.dart';
import 'billing_attention_cache.dart';
import 'billing_queue.dart';

/// Short-lived isolate batches keep DB handles bounded and independently
/// owned. The durable queue survives process termination and worker failures.
class BillingWorker {
  static final instance = BillingWorker();
  Timer? _timer;
  Future<void>? _running;
  String? _path;
  RootIsolateToken? _token;

  void start() {
    _timer?.cancel();
    _path = DatabaseHelper.instance.database.path;
    _token = RootIsolateToken.instance;
    DatabaseHelper.instance.beforeClose = stop;
    DatabaseHelper.instance.afterOpen = start;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
    _tick();
  }

  void _tick() {
    if (_running != null || _path == null) {
      return;
    }
    final request = (_path!, _token);
    _running = _run(request);
  }

  Future<void> _run((String, RootIsolateToken?) request) async {
    try {
      // A cheap outbox lookup avoids spawning an isolate while idle. All
      // source inspection/reconciliation still happens in the worker isolate.
      final pending = await DatabaseHelper.instance.database.rawQuery(
        '''
SELECT 1 FROM job_billing_state
WHERE revision != checked_revision AND retry_after <= ? LIMIT 1
''',
        [DateTime.now().millisecondsSinceEpoch],
      );
      if (pending.isEmpty) {
        return;
      }
      final checked = await runBatch(request.$1, token: request.$2);
      BillingAttentionCache.instance.reportWorkerFailure(failed: false);
      if (checked != 0 && _path == request.$1) {
        BillingAttentionCache.instance.invalidateTable('job');
      }
      if (checked == 25) {
        scheduleMicrotask(_tick);
      }
    } catch (_) {
      BillingAttentionCache.instance.reportWorkerFailure(failed: true);
      // The timer retries worker startup failures. Per-job failures/backoff
      // are persisted by BillingQueue; neither can clear a billing flag.
    } finally {
      _running = null;
    }
  }

  /// Public for an integration test with a temporary database, not a live DB.
  static Future<int> runBatch(String path, {RootIsolateToken? token}) {
    final request = (path, token);
    return Isolate.run(() => _drain(request), debugName: 'billing-queue');
  }

  static Future<int> _drain((String, RootIsolateToken?) request) async {
    if (request.$2 != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(request.$2!);
    }
    var checked = 0;
    await DatabaseHelper.instance.withOpenDatabase(
      FlutterDatabaseFactory(),
      request.$1,
      () async {
        checked = await BillingQueue(DatabaseHelper.instance.database).drain();
      },
    );
    return checked;
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _path = null;
    await _running;
  }
}

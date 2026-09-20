import 'dart:async';

import 'package:flutter/foundation.dart';

import '../entity/entity.g.dart';
import 'dao.dart';
import 'dao_job.dart';
import 'job_billing_readiness_service.dart';

/// Session-local derived data, never an authoritative billing/job status.
/// Concurrent consumers share one scan. Changes during a scan trigger another
/// pass before publishing, and a failed refresh retains the last good result.
class BillingAttentionCache extends ChangeNotifier {
  static final instance = BillingAttentionCache();

  final Future<List<JobBillingReadiness>> Function() _load;
  final Object? Function() _databaseIdentity;
  Object? _database;
  List<JobBillingReadiness>? entries;
  Object? error;
  DateTime? updatedAt;
  Future<void>? _running;
  Timer? _timer;
  var _dirty = true;
  var _disposed = false;

  BillingAttentionCache({
    Future<List<JobBillingReadiness>> Function()? load,
    Object? Function()? databaseIdentity,
  }) : _load = load ?? _loadReadyJobs,
       _databaseIdentity = databaseIdentity ?? _currentDatabase;

  bool get updating => _running != null || _timer != null;

  static Object? _currentDatabase() => DatabaseHelper.instance.isOpen()
      ? DatabaseHelper.instance.database
      : null;

  static Future<List<JobBillingReadiness>> _loadReadyJobs() async {
    final ready = <JobBillingReadiness>[];
    for (final job in await DaoJob().getByFilter(null)) {
      if (job.isStock ||
          job.billingType == BillingType.nonBillable ||
          job.status.stage == JobStatusStage.preStart ||
          job.status == JobStatus.rejected) {
        continue;
      }
      final result = await JobBillingReadinessService().evaluate(job);
      if (result.needsAttention) {
        ready.add(result);
      }
      // Yield to input/painting between jobs, even with a warm database cache.
      await Future<void>.delayed(Duration.zero);
    }
    return ready;
  }

  /// Called by the central DAO notification boundary after relevant writes.
  void invalidateTable(String table) {
    if (!const {
      'job',
      'task',
      'task_item',
      'time_entry',
      'quote',
      'quote_line',
      'quote_line_group',
      'milestone',
      'invoice',
      'invoice_line',
      'invoice_line_group',
      'receipt',
      'system',
      'task_approval',
      'task_approval_task',
      'credit_note',
      'credit_allocation',
    }.contains(table.trim())) {
      return;
    }
    _dirty = true;
    if (hasListeners) {
      requestRefresh();
    }
  }

  /// Schedule outside widget build and debounce bursts of related DAO writes.
  void requestRefresh() {
    if (_disposed) {
      return;
    }
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 250), () {
      _timer = null;
      unawaited(refresh());
    });
  }

  Future<void> refresh({bool force = false}) {
    if (_disposed) {
      return Future.value();
    }
    if (force) {
      _dirty = true;
    }
    _timer?.cancel();
    _timer = null;
    if (_running != null) {
      return _running!;
    }
    _running = Future<void>(() async {
      try {
        do {
          final database = _databaseIdentity();
          if (!identical(database, _database)) {
            _database = database;
            entries = null;
            updatedAt = null;
            _dirty = true;
          }
          if (updatedAt != null &&
              DateTime.now().difference(updatedAt!) >
                  const Duration(minutes: 2)) {
            _dirty = true;
          }
          if (!_dirty && error == null) {
            return;
          }
          _dirty = false;
          error = null;
          notifyListeners();
          final loaded = await _load();
          if (_disposed) {
            return;
          }
          if (!identical(database, _databaseIdentity())) {
            _dirty = true;
            continue;
          }
          if (!_dirty) {
            entries = List.unmodifiable(loaded);
            updatedAt = DateTime.now();
          }
        } while (_dirty && !_disposed);
      } catch (failure) {
        error = failure;
        _dirty = true;
      } finally {
        _running = null;
        if (!_disposed) {
          notifyListeners();
        }
      }
    });
    return _running!;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

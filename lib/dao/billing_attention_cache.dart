import 'dart:async';

import 'package:flutter/foundation.dart';

import '../entity/entity.g.dart';
import '../util/dart/money_ex.dart';
import 'dao.dart';
import 'job_billing_readiness_service.dart';

/// UI snapshot of persisted billing flags. Never evaluates remaining work.
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
  var pending = false;
  var initializing = false;
  var checkFailed = false;
  var workerFailed = false;

  void reportWorkerFailure({required bool failed}) {
    if (workerFailed != failed) {
      workerFailed = failed;
      notifyListeners();
    }
  }

  BillingAttentionCache({
    Future<List<JobBillingReadiness>> Function()? load,
    Object? Function()? databaseIdentity,
  }) : _load = load ?? (() async => []),
       _databaseIdentity = databaseIdentity ?? _currentDatabase,
       _usesStoredFlags = load == null;

  final bool _usesStoredFlags;

  bool get updating => pending || _running != null || _timer != null;

  static Object? _currentDatabase() => DatabaseHelper.instance.isOpen()
      ? DatabaseHelper.instance.database
      : null;

  Future<List<JobBillingReadiness>> _loadReadyJobs() async {
    final db = DatabaseHelper.instance.database;
    final states = await db.rawQuery('''
SELECT job.*, b.reason, b.billing_required, b.revision, b.checked_revision,
       b.checked_at, b.failed
FROM job_billing_state b JOIN job ON job.id = b.job_id
WHERE job.is_stock = 0
ORDER BY job.modified_date DESC
''');
    pending = states.any((row) => row['revision'] != row['checked_revision']);
    initializing = states.any((row) => row['checked_at'] == null);
    checkFailed = states.any((row) => row['failed'] == 1);
    final ready = <JobBillingReadiness>[];
    for (final row in states) {
      if (row['billing_required'] != 1) {
        continue;
      }
      final job = Job.fromMap(row);
      if (job.status.stage == JobStatusStage.preStart ||
          job.status == JobStatus.rejected) {
        continue;
      }
      final code = JobBillingReasonCode.values
          .where((code) => code.name == row['reason'])
          .firstOrNull;
      final label = switch (code) {
        JobBillingReasonCode.unbilledTimeAndMaterials => 'Unbilled work',
        JobBillingReasonCode.unbilledBookingFee => 'Unbilled booking fee',
        JobBillingReasonCode.uninvoicedMilestone => 'Uninvoiced milestone',
        JobBillingReasonCode.unallocatedQuoteAmount => 'Set up milestones',
        JobBillingReasonCode.missingApprovedQuote => 'Set up quote billing',
        _ => 'Billing check pending',
      };
      ready.add(
        JobBillingReadiness(
          job: job,
          reasons: [
            JobBillingReason(
              code: code ?? JobBillingReasonCode.unbilledTimeAndMaterials,
              label: label,
              amount: MoneyEx.zero,
              count: 1,
              invoiceable:
                  code != JobBillingReasonCode.unallocatedQuoteAmount &&
                  code != JobBillingReasonCode.missingApprovedQuote,
            ),
          ],
        ),
      );
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
          final loaded = await (_usesStoredFlags ? _loadReadyJobs() : _load());
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

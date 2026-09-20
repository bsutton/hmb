import 'dart:math';

import 'package:sqflite_common/sqlite_api.dart';

import 'job_billing_readiness_service.dart';
import 'remaining_billing.dart';

/// Persistent queue engine. The production caller runs this in an isolate.
class BillingQueue {
  final Database db;
  final Future<JobBillingReasonCode?> Function(int jobId) _check;

  BillingQueue(
    this.db, {
    Future<JobBillingReasonCode?> Function(int jobId)? check,
  }) : _check = check ?? RemainingBilling().check;

  Future<int> drain({int limit = 25}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final pending = await db.query(
      'job_billing_state',
      where: 'revision != checked_revision AND retry_after <= ?',
      whereArgs: [now],
      orderBy: 'retry_after, job_id',
      limit: limit,
    );
    for (final row in pending) {
      final id = row['job_id']! as int;
      final revision = row['revision']! as int;
      try {
        final reason = await _check(id);
        // No write lock during the check. New events make this result stale.
        await db.update(
          'job_billing_state',
          {
            'billing_required': reason == null ? 0 : 1,
            'reason': reason?.name,
            'checked_revision': revision,
            'checked_at': DateTime.now().millisecondsSinceEpoch,
            'attempts': 0,
            'retry_after': 0,
            'failed': 0,
          },
          where: 'job_id = ? AND revision = ?',
          whereArgs: [id, revision],
        );
      } catch (_) {
        final attempts = (row['attempts']! as int) + 1;
        final delay = min(300, 1 << min(attempts, 8));
        // Do not persist exception text: it could contain customer data.
        await db.update(
          'job_billing_state',
          {
            'attempts': attempts,
            'failed': 1,
            'retry_after': now + delay * 1000,
          },
          where: 'job_id = ? AND revision = ?',
          whereArgs: [id, revision],
        );
      }
    }
    return pending.length;
  }
}

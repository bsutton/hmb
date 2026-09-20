import 'package:sqflite_common/sqlite_api.dart';

import '../database/management/database_helper.dart';
import '../entity/lifecycle_transition.dart';
import '../fsm/lifecycle_models.dart';

class DaoLifecycleTransition {
  static const tableName = 'lifecycle_transition';

  Database get _db => DatabaseHelper.instance.database;

  Future<void> insert({
    required String aggregateType,
    required int aggregateId,
    required int jobId,
    required String event,
    required String fromState,
    required String toState,
    required LifecycleContext context,
    Transaction? transaction,
  }) async {
    final executor = transaction ?? _db;
    await executor.insert(tableName, {
      'aggregate_type': aggregateType,
      'aggregate_id': aggregateId,
      'job_id': jobId,
      'event': event,
      'from_state': fromState,
      'to_state': toState,
      'source': context.source,
      'reason': context.reason,
      'actor_id': context.actorId,
      'correlation_id': context.correlationId,
      'occurred_at': context.requestedAt.toIso8601String(),
    });
  }

  Future<List<LifecycleTransition>> getByJob(int jobId) async {
    final rows = await _db.query(
      tableName,
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'occurred_at DESC, id DESC',
    );
    return rows.map(LifecycleTransition.fromMap).toList();
  }
}

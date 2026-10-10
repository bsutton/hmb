import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../entity/job_activity.dart';

/// The archive also acts as an outbox. Completed rows remain as history.
class CancelledSchedule {
  static const table = 'cancelled_schedule';

  static Future<void> archiveJob(int jobId, Transaction transaction) async {
    final activities = await transaction.query(
      'job_activity',
      where: 'job_id = ?',
      whereArgs: [jobId],
    );
    for (final activity in activities) {
      await transaction.insert(table, {
        'activity_id': activity['id'],
        'job_id': jobId,
        'activity_json': jsonEncode(activity),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await transaction.delete(
      'job_activity',
      where: 'job_id = ?',
      whereArgs: [jobId],
    );
    // A queued instruction to schedule this job is no longer actionable.
    await transaction.update(
      'to_do',
      {'status': 'done', 'modified_date': DateTime.now().toIso8601String()},
      where:
          'parent_type = ? AND parent_id = ? AND status = ? '
          'AND lower(trim(title)) = ?',
      whereArgs: ['job', jobId, 'open', 'schedule job'],
    );
  }

  static JobActivity activity(Map<String, Object?> row) => JobActivity.fromMap(
    jsonDecode(row['activity_json']! as String) as Map<String, dynamic>,
  );
}

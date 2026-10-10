import 'package:sqflite_common/sqlite_api.dart';
import 'package:synchronized/synchronized.dart';

import '../../dao/cancelled_schedule.dart';
import '../../entity/job_activity.dart';
import 'google_calendar_sync.dart';

/// Explicit dependencies keep retry tests off the device and network.
class CancelledScheduleCleanup {
  CancelledScheduleCleanup({
    required this.db,
    required this.deleteCalendar,
    required this.cancelReminder,
  });

  final Database db;
  final Future<ExternalCalendarSyncResult> Function(JobActivity) deleteCalendar;
  final Future<void> Function(int) cancelReminder;
  static final _lock = Lock();
  static final _reminderLock = Lock();

  /// Serializes queued reminder writes with cancellation cleanup.
  Future<void> syncReminderIfScheduled(
    int activityId,
    Future<void> Function() sync,
  ) => _reminderLock.synchronized(() async {
    final current = await db.query(
      'job_activity',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [activityId],
    );
    if (current.isNotEmpty) {
      await sync();
    }
  });

  Future<int> pendingCount({int? jobId}) async => (await db.query(
    CancelledSchedule.table,
    columns: ['activity_id'],
    where:
        '(calendar_pending = 1 OR reminder_pending = 1)'
        '${jobId == null ? '' : ' AND job_id = ?'}',
    whereArgs: jobId == null ? null : [jobId],
  )).length;

  Future<int> retry({int? jobId}) => _lock.synchronized(() async {
    final pending = await db.query(
      CancelledSchedule.table,
      where:
          '(calendar_pending = 1 OR reminder_pending = 1)'
          '${jobId == null ? '' : ' AND job_id = ?'}',
      whereArgs: jobId == null ? null : [jobId],
    );
    for (final row in pending) {
      final activity = CancelledSchedule.activity(row);
      if (row['reminder_pending'] == 1) {
        try {
          await _reminderLock.synchronized(() => cancelReminder(activity.id));
          await _complete(activity.id, 'reminder_pending');
        } catch (_) {
          // Retain the pending flag for a later retry. Do not log private data.
        }
      }
      if (row['calendar_pending'] == 1) {
        try {
          final result = await deleteCalendar(activity);
          if (result == ExternalCalendarSyncResult.synced) {
            await _complete(activity.id, 'calendar_pending');
          }
          // Disabled, unavailable and unsigned-in are not successful deletes.
        } catch (_) {
          // One failed event must not prevent cleanup of the other bookings.
        }
      }
    }
    return await pendingCount(jobId: jobId);
  });

  Future<void> _complete(int id, String column) async {
    await db.update(
      CancelledSchedule.table,
      {column: 0},
      where: 'activity_id = ?',
      whereArgs: [id],
    );
  }
}

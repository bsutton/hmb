/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import '../entity/job_activity.dart';
import '../entity/job_status.dart';
import '../util/dart/local_date.dart';
import 'dao.dart';

class DaoJobActivity extends Dao<JobActivity> {
  static const tableName = 'job_activity';
  DaoJobActivity() : super(tableName);

  @override
  JobActivity fromMap(Map<String, dynamic> map) => JobActivity.fromMap(map);

  Future<List<JobActivity>> getByJob(int? jobId) async {
    if (jobId == null) {
      return [];
    }
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'job_id = ?',
        whereArgs: [jobId],
        orderBy: 'start_date asc',
      ),
    );
  }

  /// Returns all activities scheduled on [date].
  /// The activiites start and end date must fall within the given date.
  Future<List<JobActivity>> getActivitiesForDate(LocalDate date) async {
    final db = withoutTransaction();

    final start = date.startOfDay();
    final end = date.endOfDay();
    final results = await db.rawQuery(
      '''
SELECT ja.*
  FROM $tableName ja
  JOIN job j ON ja.job_id = j.id
 WHERE (
        (ja.start_date >= ? AND ja.start_date < ?)
        OR (ja.end_date > ? AND ja.end_date <= ?)
       )
   AND j.status_id NOT IN (?, ?)
 ORDER BY ja.start_date ASC
''',
      [
        start.toIso8601String(),
        end.toIso8601String(),
        start.toIso8601String(),
        end.toIso8601String(),
        JobStatus.rejected.id,
        JobStatus.completed.id,
      ],
    );

    // Convert each row into a JobActivity
    final jobEvents = <JobActivity>[];
    for (final row in results) {
      jobEvents.add(JobActivity.fromMap(row));
    }
    return jobEvents;
  }

  Future<List<JobActivity>> getActivitiesInRange(
    LocalDate start,
    LocalDate end,
  ) async {
    final db = withoutTransaction();

    final results = await db.rawQuery(
      '''
SELECT ja.*
  FROM $tableName ja
  JOIN job j ON ja.job_id = j.id
 WHERE (
        (ja.start_date >= ? AND ja.start_date < ?)
        OR (ja.end_date > ? AND ja.end_date <= ?)
       )
   AND j.status_id NOT IN (?, ?)
 ORDER BY ja.start_date ASC
''',
      <Object>[
        start.toIso8601String(),
        end.toIso8601String(),
        start.toIso8601String(),
        end.toIso8601String(),
        JobStatus.rejected.id,
        JobStatus.completed.id,
      ],
    );

    // Convert each row into a JobActivity
    final jobEvents = <JobActivity>[];
    for (final row in results) {
      jobEvents.add(JobActivity.fromMap(row));
    }
    return jobEvents;
  }

  Future<JobActivity?> getMostRecentByJob(int jobId) async {
    final db = withoutTransaction();
    final data = await db.rawQuery(
      '''
    SELECT *
    FROM job_activity
    WHERE job_id = ?
    ORDER BY start_date DESC
    LIMIT 1
  ''',
      [jobId],
    );

    if (data.isEmpty) {
      return null;
    }

    return fromMap(data.first);
  }

  Future<JobActivity?> getNextActivityByJob(int jobId) async {
    final db = withoutTransaction();
    final data = await db.rawQuery(
      '''
    SELECT *
    FROM job_activity
    WHERE job_id = ?
      AND start_date > ?
    ORDER BY start_date ASC
    LIMIT 1
  ''',
      [jobId, DateTime.now().toIso8601String()],
    );

    if (data.isEmpty) {
      return null;
    }

    return fromMap(data.first);
  }
}

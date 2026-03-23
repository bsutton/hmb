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

import 'package:sqflite_common/sqlite_api.dart';
import 'package:strings/strings.dart';

import '../entity/activity.dart';
import 'dao.dart';

class DaoActivity extends Dao<Activity> {
  static const tableName = 'activity';
  DaoActivity() : super(tableName);

  @override
  Activity fromMap(Map<String, dynamic> map) => Activity.fromMap(map);

  Future<List<Activity>> getByJob(
    int jobId, {
    int? limit,
    DateTime? before,
    ActivityType? type,
    ActivitySource? source,
    String? filter,
  }) async {
    final db = withoutTransaction();
    final where = <String>['job_id = ?'];
    final args = <Object?>[jobId];

    if (before != null) {
      where.add('occurred_at < ?');
      args.add(before.toIso8601String());
    }
    if (type != null) {
      where.add('type = ?');
      args.add(type.name);
    }
    if (source != null) {
      where.add('source = ?');
      args.add(source.name);
    }

    final text = (filter ?? '').trim();
    if (Strings.isNotBlank(text)) {
      where.add('''
(summary LIKE '%' || ? || '%' COLLATE NOCASE
 OR details LIKE '%' || ? || '%' COLLATE NOCASE)''');
      args
        ..add(text)
        ..add(text);
    }

    final query = StringBuffer('''
SELECT *
FROM $tableName
WHERE ${where.join(' AND ')}
ORDER BY occurred_at DESC, id DESC
''');
    if (limit != null && limit > 0) {
      query.write(' LIMIT $limit');
    }

    final rows = await db.rawQuery(query.toString(), args);
    return toList(rows);
  }

  Future<void> linkTodo({
    required int activityId,
    required int todoId,
    Transaction? transaction,
  }) async {
    final db = withinTransaction(transaction);
    await db.update(
      tableName,
      {
        'linked_todo_id': todoId,
        'modified_date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [activityId],
    );
  }

  Future<bool> hasWorkDayActivity({
    required int jobId,
    required DateTime day,
    Transaction? transaction,
  }) async {
    final db = withinTransaction(transaction);
    final rows = await db.rawQuery(
      '''
SELECT COUNT(*) AS cnt
FROM $tableName
WHERE job_id = ?
  AND source = ?
  AND type = ?
  AND date(occurred_at) = date(?)
''',
      [
        jobId,
        ActivitySource.system.name,
        ActivityType.workDay.name,
        day.toIso8601String(),
      ],
    );
    return (rows.first['cnt'] as int? ?? 0) > 0;
  }

  Future<void> recordWorkedTodayForJob({
    required int jobId,
    required DateTime day,
    Transaction? transaction,
  }) async {
    if (await hasWorkDayActivity(
      jobId: jobId,
      day: day,
      transaction: transaction,
    )) {
      return;
    }

    await insert(
      Activity.forInsert(
        jobId: jobId,
        occurredAt: day,
        source: ActivitySource.system,
        type: ActivityType.workDay,
        summary: 'Worked on job',
        details: 'Time tracking was recorded for this job.',
      ),
      transaction,
    );
  }

  Future<void> recordNavigatedToJob({required int jobId}) async {
    await insert(
      Activity.forInsert(
        jobId: jobId,
        source: ActivitySource.system,
        type: ActivityType.visit,
        summary: 'Navigated to',
      ),
    );
  }
}

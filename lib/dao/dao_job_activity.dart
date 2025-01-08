import '../entity/job_activity.dart';
import '../util/local_date.dart';
import 'dao.dart';

class DaoJobActivity extends Dao<JobActivity> {
  @override
  String get tableName => 'job_activity';

  @override
  JobActivity fromMap(Map<String, dynamic> map) => JobActivity.fromMap(map);

  Future<List<JobActivity>> getByJob(int jobId) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'start_date asc',
    );
    return toList(rows);
  }

  Future<List<JobActivity>> getActivitiesInRange(
      LocalDate start, LocalDate end) async {
    final db = withoutTransaction();

    final results = await db.query(
      tableName,
      where:
          '(start_date >= ? AND start_date < ?) OR (end_date > ? AND end_date <= ?)',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
        start.toIso8601String(),
        end.toIso8601String(),
      ],
    );

    // Convert each row into a JobEvent
    final jobEvents = <JobActivity>[];
    for (final row in results) {
      jobEvents.add(JobActivity.fromMap(row));
    }
    return jobEvents;
  }

  @override
  JobActivityState Function() get juneRefresher =>
      JobActivityState.new; // optional, if using June
}

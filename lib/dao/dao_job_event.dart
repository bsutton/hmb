// dao_job_event.dart
import '../entity/job_event.dart';
import '../util/local_date.dart';
import 'dao.dart';

class DaoJobEvent extends Dao<JobEvent> {
  @override
  String get tableName => 'job_event';

  @override
  JobEvent fromMap(Map<String, dynamic> map) => JobEvent.fromMap(map);

  Future<List<JobEvent>> getByJob(int jobId) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'start_date asc',
    );
    return toList(rows);
  }

  Future<List<JobEvent>> getEventsInRange(LocalDate start, LocalDate end) async {
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
    final jobEvents = <JobEvent>[];
    for (final row in results) {
      jobEvents.add(JobEvent.fromMap(row));
    }
    return jobEvents;
  }

  @override
  JobEventState Function() get juneRefresher =>
      JobEventState.new; // optional, if using June
}

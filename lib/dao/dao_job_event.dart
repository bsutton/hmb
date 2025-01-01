// dao_job_event.dart
import '../entity/job_event.dart';
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

  @override
  JobEventState Function() get juneRefresher =>
      JobEventState.new; // optional, if using June
}

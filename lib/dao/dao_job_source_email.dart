import 'package:sqflite_common/sqlite_api.dart';

import '../entity/job_source_email.dart';
import 'dao.dart';

class DaoJobSourceEmail extends Dao<JobSourceEmail> {
  static const tableName = 'job_source_email';

  DaoJobSourceEmail() : super(tableName);

  @override
  JobSourceEmail fromMap(Map<String, dynamic> map) =>
      JobSourceEmail.fromMap(map);

  Future<JobSourceEmail?> getByMessage({
    required String accountEmail,
    required String messageId,
    Transaction? transaction,
  }) async {
    final executor = withinTransaction(transaction);
    final rows = await executor.query(
      tableName,
      where: 'account_email = ? AND message_id = ?',
      whereArgs: [accountEmail, messageId],
      limit: 1,
    );
    final source = getFirstOrNull(rows);
    if (source == null) {
      return null;
    }

    final jobs = await executor.query(
      'job',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [source.jobId],
      limit: 1,
    );
    if (jobs.isNotEmpty) {
      return source;
    }

    await executor.delete(tableName, where: 'id = ?', whereArgs: [source.id]);
    return null;
  }

  Future<int> deleteByJob(int jobId, {Transaction? transaction}) =>
      withinTransaction(
        transaction,
      ).delete(tableName, where: 'job_id = ?', whereArgs: [jobId]);
}

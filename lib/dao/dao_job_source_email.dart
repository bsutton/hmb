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
    final rows = await withinTransaction(transaction).query(
      tableName,
      where: 'account_email = ? AND message_id = ?',
      whereArgs: [accountEmail, messageId],
      limit: 1,
    );
    return getFirstOrNull(rows);
  }
}

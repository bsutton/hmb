import 'package:june/june.dart';
import 'package:strings/strings.dart';

import '../entity/task_status.dart';
import 'dao.dart';

class DaoTaskStatus extends Dao<TaskStatus> {
  @override
  String get tableName => 'task_status';

  /// search for jobs given a user supplied filter string.
  Future<List<TaskStatus>> getByFilter(String? filter) async {
    final db = getDb();

    if (Strings.isBlank(filter)) {
      return getAll();
    }

    final likeArg = '''%$filter%''';
    final data = await db.rawQuery('''
select ts.*
from task_status ts 
where ts.name like ?
or ts.description like ?
''', [likeArg, likeArg]);

    return toList(data);
  }

  @override
  TaskStatus fromMap(Map<String, dynamic> map) => TaskStatus.fromMap(map);
  @override
  JuneStateCreator get juneRefresher => TaskStatusState.new;
}

/// Used to notify the UI that the time entry has changed.
class TaskStatusState extends JuneState {
  TaskStatusState();
}

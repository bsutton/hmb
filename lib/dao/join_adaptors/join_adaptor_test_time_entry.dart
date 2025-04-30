import '../../entity/task.dart';
import '../../entity/time_entry.dart';
import '../dao_time_entry.dart';
import 'dao_join_adaptor.dart';

class JoinAdaptorTaskTimeEntry extends DaoJoinAdaptor<TimeEntry, Task> {
  @override
  Future<void> deleteFromParent(TimeEntry child, Task parent) async {
    // await DaoTimeEntryTask().deleteJoin(task, timeEntry);
    // there is no join table.
  }

  @override
  Future<List<TimeEntry>> getByParent(Task? parent)  =>
      DaoTimeEntry().getByTask(parent?.id);

  @override
  Future<void> insertForParent(TimeEntry child, Task parent) async {
    // await DaoTimeEntry().insertForTask(timeEntry, task);
  }

  @override
  Future<void> setAsPrimary(TimeEntry child, Task parent) {
    // not used.
    throw UnimplementedError();
  }
}

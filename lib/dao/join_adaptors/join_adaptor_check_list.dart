// ignore_for_file: library_private_types_in_public_api

import '../../entity/check_list.dart';
import '../../entity/task.dart';
import '../dao_check_list_task.dart';
import '../dao_checklist.dart';
import '../dao_checklist_item.dart';
import 'dao_join_adaptor.dart';

class JoinAdaptorTaskCheckList implements DaoJoinAdaptor<CheckList, Task> {
  @override
  Future<void> deleteFromParent(CheckList checklist, Task task) async {
    await DaoCheckListTask().deleteJoin(task, checklist);
    await DaoCheckListItem().deleteByChecklist(checklist);
    await DaoCheckList().delete(checklist.id);
  }

  @override
  Future<List<CheckList>> getByParent(Task? task) async {
    final checklist = await DaoCheckList().getByTask(task?.id);

    if (checklist == null) {
      return [];
    }

    return [checklist];
  }

  @override
  Future<void> insertForParent(CheckList checklist, Task task) async {
    await DaoCheckList().insertForTask(checklist, task);
  }

  @override
  Future<void> setAsPrimary(CheckList child, Task task) async {
    await DaoCheckListTask().setAsPrimary(child, task);
  }
}

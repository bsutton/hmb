// ignore_for_file: library_private_types_in_public_api

import '../../entity/check_list.dart';
import '../../entity/check_list_item.dart';
import '../dao_check_list_item_check_list.dart';
import '../dao_checklist_item.dart';
import 'dao_join_adaptor.dart';

class JoinAdaptorCheckListCheckListItem
    implements DaoJoinAdaptor<CheckListItem, CheckList> {
  @override
  Future<void> deleteFromParent(
      CheckListItem checklistItem, CheckList checklist) async {
    await DaoCheckListItemCheckList().deleteJoin(checklist, checklistItem);
    await DaoCheckListItem().delete(checklistItem.id);
  }

  @override
  Future<List<CheckListItem>> getByParent(CheckList? checklist) async =>
      DaoCheckListItem().getByCheckList(checklist!);

  @override
  Future<void> insertForParent(
      CheckListItem checklistitem, CheckList checklist) async {
    await DaoCheckListItem().insertForCheckList(checklistitem, checklist);
  }

  @override
  Future<void> setAsPrimary(CheckListItem child, CheckList parent) {
    /// Not required for a check list item.
    throw UnimplementedError();
  }
}

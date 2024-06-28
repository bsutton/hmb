import 'package:flutter/material.dart';

import '../../dao/dao_checklist.dart';
import '../../dao/join_adaptors/dao_join_adaptor.dart';
import '../../entity/check_list.dart';
import '../../entity/entity.dart';
import '../../widgets/hmb_text.dart';
import '../base_nested/nested_list_screen.dart';
import 'checklist_edit_screen.dart';

class CheckListListScreen<P extends Entity<P>> extends StatelessWidget {
  const CheckListListScreen({
    required this.parent,
    required this.parentTitle,
    required this.daoJoin,
    super.key,
    this.checkListType,
  });

  final Parent<P> parent;
  final String parentTitle;

  final DaoJoinAdaptor<CheckList, P> daoJoin;
  final CheckListType? checkListType;

  @override
  Widget build(BuildContext context) => NestedEntityListScreen<CheckList, P>(
      parent: parent,
      entityNamePlural: 'CheckLists',
      parentTitle: parentTitle,
      entityNameSingular: 'CheckList',
      dao: DaoCheckList(),
      onDelete: (checklist) async =>
          daoJoin.deleteFromParent(checklist!, parent.parent!),
      onInsert: (checklist) async =>
          daoJoin.insertForParent(checklist!, parent.parent!),
      // ignore: discarded_futures
      fetchList: () => daoJoin.getByParent(parent.parent),
      title: (checklist) =>
          Text('${checklist.name} ${checklist.description}') as Widget,
      onEdit: (checklist) => CheckListEditScreen(
          daoJoin: daoJoin,
          parent: parent.parent!,
          checklist: checklist,
          checkListType: checkListType),
      details: (entity, details) {
        final checklist = entity;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [HMBText(checklist.name)]);
      });
}

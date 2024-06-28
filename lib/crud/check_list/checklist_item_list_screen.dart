import 'package:flutter/material.dart';

import '../../dao/dao_checklist_item.dart';
import '../../dao/join_adaptors/dao_join_adaptor.dart';
import '../../entity/check_list_item.dart';
import '../../entity/check_list_item_type.dart';
import '../../entity/entity.dart';
import '../../widgets/hmb_money.dart';
import '../base_nested/nested_list_screen.dart';
import 'checklist_item_edit_screen.dart';

class CheckListItemListScreen<P extends Entity<P>> extends StatelessWidget {
  const CheckListItemListScreen({
    required this.parent,
    required this.daoJoin,
    super.key,
    this.checkListItemType,
  });

  final Parent<P> parent;

  final DaoJoinAdaptor<CheckListItem, P> daoJoin;
  final CheckListItemType? checkListItemType;

  @override
  Widget build(BuildContext context) =>
      NestedEntityListScreen<CheckListItem, P>(
          parent: parent,
          parentTitle: 'Check List',
          entityNameSingular: 'Check List Item',
          entityNamePlural: 'Items',
          dao: DaoCheckListItem(),
          onDelete: (checklistitem) async =>
              daoJoin.deleteFromParent(checklistitem!, parent.parent!),
          onInsert: (checklistitem) async =>
              daoJoin.insertForParent(checklistitem!, parent.parent!),
          // ignore: discarded_futures
          fetchList: () => daoJoin.getByParent(parent.parent),
          title: (checklistitem) => Text(checklistitem.description) as Widget,
          onEdit: (checklistitem) => CheckListItemEditScreen(
                daoJoin: daoJoin,
                parent: parent.parent!,
                checkListItem: checklistitem,
              ),
          details: (entity, details) {
            final checklistitem = entity;
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HMBMoney(label: 'Cost', amount: checklistitem.cost)
                ]);
          });
}

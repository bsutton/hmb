// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';

import '../crud/base_nested/list_nested_screen.dart';
import '../crud/check_list/list_checklist_screen.dart';
import '../dao/join_adaptors/dao_join_adaptor.dart';
import '../entity/check_list.dart';
import '../entity/entity.dart';
import 'hmb_child_crud_card.dart';

class HBMCrudCheckList<P extends Entity<P>> extends StatelessWidget {
  const HBMCrudCheckList({
    required this.parent,
    required this.parentTitle,
    required this.daoJoin,
    this.checkListType = CheckListType.owned,
    super.key,
  });

  final DaoJoinAdaptor<CheckList, P> daoJoin;
  final Parent<P> parent;
  final CheckListType checkListType;
  final String parentTitle;

  @override
  Widget build(BuildContext context) => HMBChildCrudCard(
      headline: 'CheckLists',
      crudListScreen: CheckListListScreen(
          parentTitle: parentTitle,
          daoJoin: daoJoin,
          parent: parent,
          checkListType: checkListType));
}

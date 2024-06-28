// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';

import '../crud/base_nested/nested_list_screen.dart';
import '../crud/check_list/checklist_item_list_screen.dart';
import '../dao/join_adaptors/dao_join_adaptor.dart';
import '../entity/check_list_item.dart';
import '../entity/entity.dart';
import 'hmb_child_crud_card.dart';

class HBMCrudCheckListItem<P extends Entity<P>> extends StatelessWidget {
  const HBMCrudCheckListItem({
    required this.parent,
    required this.daoJoin,
    super.key,
  });

  final DaoJoinAdaptor<CheckListItem, P> daoJoin;
  final Parent<P> parent;

  @override
  Widget build(BuildContext context) => HMBChildCrudCard(
      headline: 'Items',
      crudListScreen:
          CheckListItemListScreen(daoJoin: daoJoin, parent: parent));
}

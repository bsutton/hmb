// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';

import '../crud/base_nested/list_nested_screen.dart';
import '../crud/site/list_site_screen.dart';
import '../dao/join_adaptors/dao_join_adaptor.dart';
import '../entity/entity.dart';
import '../entity/site.dart';
import 'hmb_child_crud_card.dart';

class HBMCrudSite<P extends Entity<P>> extends StatelessWidget {
  const HBMCrudSite({
    required this.parent,
    required this.daoJoin,
    required this.parentTitle,
    super.key,
  });

  final DaoJoinAdaptor<Site, P> daoJoin;
  final Parent<P> parent;
  final String parentTitle;

  @override
  Widget build(BuildContext context) => HMBChildCrudCard(
      headline: 'Sites',
      crudListScreen: SiteListScreen(
        daoJoin: daoJoin,
        parent: parent,
        parentTitle: parentTitle,
      ));
}

import 'package:flutter/material.dart';

import '../../../dao/dao_site.dart';
import '../../../dao/join_adaptors/dao_join_adaptor.dart';
import '../../../entity/entity.dart';
import '../../../entity/site.dart';
import '../../widgets/text/hmb_site_text.dart';
import '../base_nested/list_nested_screen.dart';
import 'edit_site_screen.dart';

class SiteListScreen<P extends Entity<P>> extends StatelessWidget {
  const SiteListScreen({
    required this.parent,
    required this.daoJoin,
    required this.parentTitle,
    super.key,
  });

  final Parent<P> parent;

  final DaoJoinAdaptor<Site, P> daoJoin;
  final String parentTitle;

  @override
  Widget build(BuildContext context) => NestedEntityListScreen<Site, P>(
    parent: parent,
    entityNamePlural: 'Sites',
    entityNameSingular: 'Site',
    parentTitle: parentTitle,
    dao: DaoSite(),
    // ignore: discarded_futures
    onDelete: (site) => daoJoin.deleteFromParent(site!, parent.parent!),
    // ignore: discarded_futures
    onInsert: (site) => daoJoin.insertForParent(site!, parent.parent!),
    // ignore: discarded_futures
    fetchList: () => daoJoin.getByParent(parent.parent),
    // title: (site) => Text('${site.addressLine1} ${site.suburb}') as Widget,
    title: (site) => HMBSiteText(label: '', site: site),
    onEdit:
        (site) => SiteEditScreen(
          daoJoin: daoJoin,
          parent: parent.parent!,
          site: site,
        ),
    details:
        (entity, details) =>
            const Column(crossAxisAlignment: CrossAxisAlignment.start),
  );
}

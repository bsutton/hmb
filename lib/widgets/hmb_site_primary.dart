import 'package:flutter/material.dart';

import '../crud/site/site_edit_screen.dart';
import '../dao/join_adaptors/dao_join_adaptor.dart';
import '../entity/entity.dart';
import '../entity/site.dart';
import 'hmb_add_button.dart';

/// Displays the primary site of a parent
/// and allows the user to select/update the primary site.
class HMBSitePrimary<P extends Entity<P>> extends StatefulWidget {
  const HMBSitePrimary(
      {required this.label,
      required this.parent,
      required this.site,
      required this.daoJoin,
      super.key});
  final String label;
  final Site? site;
  final P parent;
  final DaoJoinAdaptor<Site, P> daoJoin;

  @override
  State<HMBSitePrimary<P>> createState() => _HMBSitePrimaryState<P>();
}

class _HMBSitePrimaryState<P extends Entity<P>>
    extends State<HMBSitePrimary<P>> {
  Site? site;
  @override
  void initState() {
    super.initState();
    site = widget.site;
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          if (widget.site != null) Text(widget.label),
          if (site != null) Text('''
${widget.site?.addressLine1}, ${widget.site?.addressLine2}, ${widget.site?.suburb}, ${widget.site?.state}, ${widget.site?.postcode}'''),
          HMBButtonAdd(
              enabled: true,
              onPressed: () async {
                final site = await Navigator.push<Site>(
                  context,
                  MaterialPageRoute<Site>(
                      builder: (context) => SiteEditScreen(
                          parent: widget.parent, daoJoin: widget.daoJoin)),
                );
                setState(() {
                  if (site != null) {
                    widget.daoJoin.setAsPrimary(site, widget.parent);
                  }
                  this.site = site;
                });
              })
        ],
      );
}

/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../../dao/join_adaptors/dao_join_adaptor.dart';
import '../../entity/entity.dart';
import '../../entity/site.dart';
import '../crud/site/edit_site_screen.dart';
import 'hmb_add_button.dart';

/// Displays the primary site of a parent
/// and allows the user to select/update the primary site.
class HMBSitePrimary<P extends Entity<P>> extends StatefulWidget {
  const HMBSitePrimary({
    required this.label,
    required this.parent,
    required this.site,
    required this.daoJoin,
    super.key,
  });
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
      if (site != null)
        Text(
          '''
${widget.site?.addressLine1}, ${widget.site?.addressLine2}, ${widget.site?.suburb}, ${widget.site?.state}, ${widget.site?.postcode}''',
        ),
      HMBButtonAdd(
        enabled: true,
        onAdd: () async {
          final site = await Navigator.push<Site>(
            context,
            MaterialPageRoute<Site>(
              builder: (context) => SiteEditScreen(
                parent: widget.parent,
                daoJoin: widget.daoJoin,
              ),
            ),
          );
          if (site != null) {
            await widget.daoJoin.setAsPrimary(site, widget.parent);
          }
          setState(() {
            this.site = site;
          });
        },
      ),
    ],
  );
}

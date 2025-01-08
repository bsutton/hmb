import 'package:flutter/material.dart';

import '../../../dao/dao_site.dart';
import '../../../entity/customer.dart';
import '../../../entity/site.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../message_template_dialog.dart';
import 'source.dart';

class SiteSource extends Source<Site> {
  SiteSource() : super(name: 'site');

  Customer? customer;

  Site? site;

  @override
  Widget widget(MessageData data) => HMBDroplist<Site>(
      title: 'Site',
      selectedItem: () async => value,
      items: (filter) async {
        if (site != null) {
          return DaoSite().getByCustomer(customer?.id);
        } else {
          return [];
        }
      },
      format: (site) => site.address,
      onChanged: (site) => this.site = site);

  @override
  Site? get value => site;
}

// /// Site placeholder drop list
// PlaceHolderField<Site> _buildSiteDroplist(
//     SiteHolder siteHolder, MessageData data) {
//   final droplist = HMBDroplist<Site>(
//     title: siteHolder.name.toCapitalised(),
//     selectedItem: () async => siteHolder.site = data.site,
//     items: (filter) async {
//       if (data.customer != null) {
//         // Fetch sites associated with the selected customer
//         return DaoSite().getByFilter(data.customer!.id, filter);
//       } else {
//         // Fetch all sites
//         return DaoSite().getAll();
//       }
//     },
//     format: (site) => site.address,
//     onChanged: (site) {
//       siteHolder.site = site;
//       siteHolder.onChanged?.call(site, ResetFields());
//     },
//   );
//   return PlaceHolderField<Site>(
//     placeholder: siteHolder,
//     widget: droplist,
//     getValue: (data) async => siteHolder.value(data),
//   );

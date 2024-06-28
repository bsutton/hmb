import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../crud/site/site_edit_screen.dart';
import '../dao/dao_site.dart';
import '../dao/join_adaptors/join_adaptor_customer_site.dart';
import '../entity/customer.dart';
import '../entity/site.dart';
import 'hmb_add_button.dart';
import 'hmb_droplist.dart';

/// Allows the user to select a Primary Site from the sites
/// owned by a customer and and the associate them with another
/// entity e.g. a job.
class HMBSelectSite extends StatefulWidget {
  const HMBSelectSite(
      {required this.initialSite, required this.customer, super.key});

  /// The customer that owns the site.
  final Customer? customer;
  final SelectedSite initialSite;

  @override
  HMBSelectSiteState createState() => HMBSelectSiteState();
}

class HMBSelectSiteState extends State<HMBSelectSite> {
  @override
  Widget build(BuildContext context) {
    if (widget.customer == null) {
      return const Center(child: Text('Sites: Select a customer first.'));
    } else {
      return Row(
        children: [
          Expanded(
            child: HMBDroplist<Site>(
                title: 'Site',
                initialItem: () async =>
                    DaoSite().getById(widget.initialSite.siteId),
                onChanged: (newValue) {
                  setState(() {
                    widget.initialSite.siteId = newValue.id;
                  });
                },
                items: (filter) async =>
                    DaoSite().getByFilter(widget.customer, filter),
                format: (site) => site.abbreviated(),
                required: false),
          ),
          HMBButtonAdd(
              enabled: true,
              onPressed: () async {
                final customer = await Navigator.push<Site>(
                  context,
                  MaterialPageRoute<Site>(
                      builder: (context) => SiteEditScreen<Customer>(
                          parent: widget.customer!,
                          daoJoin: JoinAdaptorCustomerSite())),
                );
                setState(() {
                  widget.initialSite.siteId = customer?.id;
                });
              }),
        ],
      );
    }
  }
}

class SelectedSite extends JuneState {
  SelectedSite();

  int? siteId;
}

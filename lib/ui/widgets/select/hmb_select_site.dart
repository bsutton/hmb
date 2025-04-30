import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao_site.dart';
import '../../../dao/join_adaptors/join_adaptor_customer_site.dart';
import '../../../entity/customer.dart';
import '../../../entity/site.dart';
import '../../../ui/widgets/hmb_add_button.dart';
import '../../crud/site/edit_site_screen.dart';
import 'hmb_droplist.dart';

/// Allows the user to select a Primary Site from the sites
/// owned by a customer and associate them with another
/// entity e.g. a job.
class HMBSelectSite extends StatefulWidget {
  const HMBSelectSite({
    required this.initialSite,
    required this.customer,
    super.key,
    this.onSelected,
  });

  /// The customer that owns the site.
  final Customer? customer;
  final SelectedSite initialSite;
  final void Function(Site? site)? onSelected;

  @override
  HMBSelectSiteState createState() => HMBSelectSiteState();
}

class HMBSelectSiteState extends State<HMBSelectSite> {
  Future<Site?> _getInitialSite() =>
      DaoSite().getById(widget.initialSite.siteId);

  Future<List<Site>> _getSites(String? filter) =>
      DaoSite().getByFilter(widget.customer?.id, filter);

  void _onSiteChanged(Site? newValue) {
    setState(() {
      widget.initialSite.siteId = newValue?.id;
    });
    widget.onSelected?.call(newValue);
  }

  Future<void> _addSite() async {
    final site = await Navigator.push<Site>(
      context,
      MaterialPageRoute<Site>(
        builder:
            (context) => SiteEditScreen<Customer>(
              parent: widget.customer!,
              daoJoin: JoinAdaptorCustomerSite(),
            ),
      ),
    );
    if (site != null) {
      setState(() {
        widget.initialSite.siteId = site.id;
      });
      widget.onSelected?.call(site);
    }
  }

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
              selectedItem: _getInitialSite,
              onChanged: _onSiteChanged,
              items: _getSites,
              format: (site) => site.abbreviated(),
              required: false,
            ),
          ),
          HMBButtonAdd(enabled: true, onPressed: _addSite),
        ],
      );
    }
  }
}

class SelectedSite extends JuneState {
  SelectedSite();

  int? siteId;
}

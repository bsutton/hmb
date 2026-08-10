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
import 'package:june/june.dart';

import '../../../dao/dao_site.dart';
import '../../../dao/join_adaptors/join_adaptor_customer_site.dart';
import '../../../entity/customer.dart';
import '../../../entity/job.dart';
import '../../../entity/site.dart';
import '../../crud/site/edit_site_screen.dart';
import '../icons/hmb_add_button.dart';
import 'hmb_droplist.dart';

/// Allows the user to select a Primary Site from the sites
/// owned by a customer and associate them with another
/// entity e.g. a job.
class HMBSelectSite extends StatefulWidget {
  /// The customer that owns the site.
  final Customer? customer;
  final SelectedSite initialSite;
  final Job? associatedJob;
  final void Function(Site? site)? onSelected;

  const HMBSelectSite({
    required this.initialSite,
    required this.customer,
    this.associatedJob,
    super.key,
    this.onSelected,
  });

  @override
  HMBSelectSiteState createState() => HMBSelectSiteState();
}

class HMBSelectSiteState extends State<HMBSelectSite> {
  Future<Site?> _getInitialSite() async {
    if (widget.initialSite.siteId != null) {
      return DaoSite().getById(widget.initialSite.siteId);
    }

    final sites = await DaoSite().getByFilter(widget.customer?.id, null);
    if (sites.length != 1) {
      final site = await DaoSite().getByJob(widget.associatedJob);
      if (site == null) {
        return null;
      }
      widget.initialSite.siteId = site.id;
      widget.onSelected?.call(site);
      return site;
    }

    final site = sites.first;
    widget.initialSite.siteId = site.id;
    widget.onSelected?.call(site);
    return site;
  }

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
        builder: (context) => SiteEditScreen<Customer>(
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
          HMBButtonAdd(enabled: true, onAdd: _addSite),
        ],
      );
    }
  }
}

class SelectedSite extends JuneState {
  int? _siteId;

  SelectedSite();

  int? get siteId => _siteId;

  set siteId(int? value) {
    _siteId = value;
    setState();
  }
}

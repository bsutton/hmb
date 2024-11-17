import 'package:strings/strings.dart';

import '../../../dao/dao_site.dart';
import '../../../entity/site.dart';
import '../../select/hmb_droplist.dart';
import '../message_template_dialog.dart';
import 'place_holder.dart';

class SiteHolder extends PlaceHolder<Site> {
  SiteHolder() : super(name: keyName, key: keyScope);

  static String keyName = 'site';
  static String keyScope = 'site';

  Site? site;
  @override
  Future<String> value(MessageData data) async => site?.address ?? '';

  @override
  PlaceHolderField<Site> field(MessageData data) =>
      _buildSiteDroplist(this, data);

  @override
  void setValue(Site? value) => site = value;
}

/// Site placeholder drop list
PlaceHolderField<Site> _buildSiteDroplist(
    SiteHolder siteHolder, MessageData data) {
  final droplist = HMBDroplist<Site>(
    title: siteHolder.name.toCapitalised(),
    selectedItem: () async => siteHolder.site = data.site,
    items: (filter) async {
      if (data.customer != null) {
        // Fetch sites associated with the selected customer
        return DaoSite().getByFilter(data.customer!.id, filter);
      } else {
        // Fetch all sites
        return DaoSite().getAll();
      }
    },
    format: (site) => site.address,
    onChanged: (site) {
      siteHolder.site = site;
      siteHolder.onChanged?.call(site, ResetFields());
    },
  );
  return PlaceHolderField<Site>(
    placeholder: siteHolder,
    widget: droplist,
    getValue: (data) async => siteHolder.value(data),
  );
}

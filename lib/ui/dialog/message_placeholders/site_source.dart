/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../../../dao/dao_site.dart';
import '../../../entity/customer.dart';
import '../../../entity/site.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../source_context.dart';
import 'source.dart';

class SiteSource extends Source<Site> {
  SiteSource() : super(name: 'site');
  final customerNotifier = ValueNotifier<Customer?>(null);

  Site? site;

  @override
  Widget widget() => ValueListenableBuilder(
    valueListenable: customerNotifier,
    builder: (context, customer, _) => HMBDroplist<Site>(
      key: ValueKey(customer),
      title: 'Site',
      selectedItem: () async => value,
      // ignore: discarded_futures
      items: (filter) => DaoSite().getByCustomer(customer?.id),
      format: (site) => site.address,
      onChanged: (site) {
        this.site = site;
        onChanged(site, ResetFields());
      },
    ),
  );

  @override
  Site? get value => site;

  @override
  void dependencyChanged(Source<dynamic> source, SourceContext sourceContext) {
    if (source == this) {
      return;
    }

    customerNotifier.value = sourceContext.customer;
    site = null;
  }

  @override
  void revise(SourceContext sourceContext) {
    sourceContext.site = site;
  }
}

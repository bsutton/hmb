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
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao_contact.dart';
import '../../../dao/dao_site.dart';
import '../../../dao/dao_supplier.dart';
import '../../../entity/supplier.dart';
import '../../dialog/source_context.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/text/contact_text.dart';
import '../../widgets/text/hmb_email_text.dart';
import '../../widgets/text/hmb_phone_text.dart';
import '../../widgets/text/hmb_site_text.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'edit_supplier_screen.dart';

class SupplierListScreen extends StatelessWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context) => EntityListScreen<Supplier>(
    entityNameSingular: 'Supplier',
    entityNamePlural: 'Suppliers',
    dao: DaoSupplier(),
    listCardTitle: (entity) => HMBCardHeading(entity.name),
    // ignore: discarded_futures
    fetchList: (filter) => DaoSupplier().getByFilter(filter),
    onEdit: (supplier) => SupplierEditScreen(supplier: supplier),
    listCard: (entity) {
      final supplier = entity;
      return FutureBuilderEx(
        // ignore: discarded_futures
        future: DaoSite().getPrimaryForSupplier(supplier),
        builder: (context, site) => FutureBuilderEx(
          // ignore: discarded_futures
          future: DaoContact().getPrimaryForSupplier(supplier),
          builder: (context, contact) => HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HMBTextBody(supplier.service ?? ''),
              ContactText(label: '', contact: contact),
              HMBPhoneText(
                phoneNo: contact?.bestPhone,
                sourceContext: SourceContext(supplier: supplier),
              ),
              HMBEmailText(email: contact?.emailAddress),
              HMBSiteText(label: '', site: site),
            ],
          ),
        ),
      );
    },
  );
}

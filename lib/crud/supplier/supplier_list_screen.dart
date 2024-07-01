import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_contact.dart';
import '../../dao/dao_site.dart';
import '../../dao/dao_supplier.dart';
import '../../entity/supplier.dart';
import '../../widgets/contact_text.dart';
import '../../widgets/hmb_email_text.dart';
import '../../widgets/hmb_phone_text.dart';
import '../../widgets/hmb_site_text.dart';
import '../../widgets/hmb_text_themes.dart';
import '../base_full_screen/entity_list_screen.dart';
import 'supplier_edit_screen.dart';

class SupplierListScreen extends StatelessWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context) => EntityListScreen<Supplier>(
      pageTitle: 'Suppliers',
      dao: DaoSupplier(),
      title: (entity) => HMBTextHeadline2(entity.name),
      fetchList: (filter) async => DaoSupplier().getByFilter(filter),
      onEdit: (supplier) => SupplierEditScreen(supplier: supplier),
      details: (entity) {
        final supplier = entity;
        return FutureBuilderEx(
            // ignore: discarded_futures
            future: DaoSite().getPrimaryForSupplier(supplier),
            builder: (context, site) => FutureBuilderEx(
                // ignore: discarded_futures
                future: DaoContact().getPrimaryForSupplier(supplier),
                builder: (context, contact) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HMBTextBody(supplier.service ?? ''),
                          ContactText(label: '', contact: contact),
                          HMBPhoneText(phoneNo: contact?.mobileNumber),
                          HMBEmailText(email: contact?.emailAddress),
                          HMBSiteText(label: '', site: site)
                        ])));
      });
}

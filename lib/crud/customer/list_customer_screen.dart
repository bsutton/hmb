import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao.dart';
import '../../dao/dao_contact.dart';
import '../../dao/dao_site.dart';
import '../../entity/customer.dart';
import '../../widgets/contact_text.dart';
import '../../widgets/hmb_email_text.dart';
import '../../widgets/hmb_phone_text.dart';
import '../../widgets/hmb_placeholder.dart';
import '../../widgets/hmb_site_text.dart';
import '../../widgets/hmb_text_themes.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'edit_customer_screen.dart';

class CustomerListScreen extends StatelessWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context) => EntityListScreen<Customer>(
      pageTitle: 'Customers',
      dao: DaoCustomer(),
      title: (entity) => HMBTextHeadline2(entity.name),
      fetchList: (filter) async => DaoCustomer().getByFilter(filter),
      onEdit: (customer) => CustomerEditScreen(customer: customer),
      details: (entity) {
        final customer = entity;
        return FutureBuilderEx(
          waitingBuilder: (context) => const HMBPlaceHolder(height: 145),
            // ignore: discarded_futures
            future: DaoSite().getPrimaryForCustomer(customer.id),
            builder: (context, site) => FutureBuilderEx(
              waitingBuilder: (context) => const HMBPlaceHolder(height: 145),
                // ignore: discarded_futures
                future: DaoContact().getPrimaryForCustomer(customer.id),
                builder: (context, contact) => Column(
                  mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ContactText(
                              label: 'Primary Contact:', contact: contact),
                          HMBPhoneText(
                              label: '', phoneNo: contact?.mobileNumber),
                          HMBEmailText(label: '', email: contact?.emailAddress),
                          HMBSiteText(label: '', site: site)
                        ])));
      });
}

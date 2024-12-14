import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao_contact.dart';
import '../../../dao/dao_customer.dart';
import '../../../dao/dao_site.dart';
import '../../../entity/customer.dart';
import '../../dialog/message_template_dialog.dart';
import '../../widgets/layout/hmb_placeholder.dart';
import '../../widgets/text/contact_text.dart';
import '../../widgets/text/hmb_email_text.dart';
import '../../widgets/text/hmb_phone_text.dart';
import '../../widgets/text/hmb_site_text.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'edit_customer_screen.dart';

class CustomerListScreen extends StatelessWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context) => EntityListScreen<Customer>(
      pageTitle: 'Customers',
      dao: DaoCustomer(),
      title: (entity) => HMBCardHeading(entity.name),
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
                              label: '',
                              phoneNo: contact?.bestPhone,
                              messageData: MessageData(
                                  contact: contact, customer: customer)),
                          HMBEmailText(label: '', email: contact?.emailAddress),
                          HMBSiteText(label: '', site: site)
                        ])));
      });
}

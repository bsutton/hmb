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
import '../../../entity/entity.g.dart';
import '../../dialog/source_context.dart';
import '../../widgets/layout/hmb_column.dart';
import '../../widgets/layout/hmb_full_page_child_screen.dart';
import '../../widgets/layout/hmb_placeholder.dart';
import '../../widgets/text/contact_text.dart';
import '../../widgets/text/hmb_email_text.dart';
import '../../widgets/text/hmb_phone_text.dart';
import '../../widgets/text/hmb_site_text.dart';
import '../../widgets/text/hmb_text_themes.dart';

class ListCustomerCard extends StatelessWidget {
  final Customer customer;

  const ListCustomerCard({required this.customer, super.key});

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
    waitingBuilder: (context) => const HMBPlaceHolder(height: 145),
    future: DaoSite().getPrimaryForCustomer(customer.id),
    builder: (context, site) => FutureBuilderEx(
      waitingBuilder: (context) => const HMBPlaceHolder(height: 145),
      future: DaoContact().getPrimaryForCustomer(customer.id),
      builder: (context, contact) => HMBColumn(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContactText(label: 'Primary Contact:', contact: contact),
          HMBPhoneText(
            label: '',
            phoneNo: contact?.bestPhone,
            sourceContext: SourceContext(contact: contact, customer: customer),
          ),
          HMBEmailText(label: '', email: contact?.emailAddress),
          HMBSiteText(label: '', site: site),
        ],
      ),
    ),
  );
}

class FullPageListCustomerCard extends StatelessWidget {
  final Customer customer;

  const FullPageListCustomerCard(this.customer, {super.key});

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Customer',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HMBCardHeading(customer.name),
        ListCustomerCard(customer: customer),
      ],
    ),
  );
}

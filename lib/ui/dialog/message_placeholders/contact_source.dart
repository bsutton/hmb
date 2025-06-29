/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../../../dao/dao_contact.dart';
import '../../../entity/contact.dart';
import '../../../entity/customer.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../source_context.dart';
import 'source.dart';

class ContactSource extends Source<Contact> {
  ContactSource() : super(name: 'contact');
  final customerNotifier = ValueNotifier<CustomerContact>(
    CustomerContact(null, null),
  );

  Contact? contact;

  @override
  Widget widget() => ValueListenableBuilder(
    valueListenable: customerNotifier,
    builder: (context, customerContact, _) => HMBDroplist<Contact>(
      title: 'Contact',
      selectedItem: () async => customerContact.contact,
      items: (filter) =>
          // ignore: discarded_futures
          DaoContact().getByFilter(customerContact.customer!, filter),
      format: (contact) => contact.fullname,
      onChanged: (contact) {
        this.contact = contact;
        // Reset site and contact when customer changes
        onChanged.call(contact, ResetFields(site: true, contact: true));
      },
    ),
  );

  @override
  Contact? get value => contact;

  @override
  void dependencyChanged(Source<dynamic> source, SourceContext sourceContext) {
    if (source == this) {
      return;
    }
    customerNotifier.value = CustomerContact(
      sourceContext.customer,
      sourceContext.contact,
    );
    contact = null;
  }

  @override
  void revise(SourceContext sourceContext) {
    sourceContext.contact = contact;
  }
}

class CustomerContact {
  CustomerContact(this.customer, this.contact);
  Customer? customer;
  Contact? contact;
}

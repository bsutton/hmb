import 'package:flutter/material.dart';

import '../../../dao/dao_contact.dart';
import '../../../dao/dao_customer.dart';
import '../../../entity/contact.dart';
import '../../../entity/customer.dart';
import '../../select/hmb_droplist.dart';
import '../message_template_dialog.dart';
import 'contact_holder.dart';
import 'place_holder.dart';
import 'source.dart';

class ContactSource extends Source<Contact> {
  ContactSource() : super(name: 'contact');

  /// needs be taken from th emanager.
  Customer? customer;
  Contact? contact;

  @override
  Widget field(MessageData data) => _buildContactDroplist(ContactName(), data);

  // HMBDroplist<Contact>(
  //       title: 'Contact',
  //       selectedItem: () async => contact,
  //       items: (filter) async => DaoContact().getByFilter(customer!, filter),
  //       format: (contact) => contact.fullname,
  //       onChanged: (contact) {
  //         this.contact = contact;
  //         // Reset site and contact when customer changes
  //         onChanged?.call(contact, ResetFields(site: true, contact: true));
  //       },
  //     );
}

// => HMBDroplist<Customer>(
//         title: 'Customer',
//         selectedItem: () async => value,
//         items: (filter) async => DaoCustomer().getByFilter(filter),
//         format: (customer) => customer.name,
//         onChanged: setValue,
//       );

/// Contact placeholder drop list
Widget _buildContactDroplist(ContactName placeholder, MessageData data) {
  placeholder.setValue(data.contact);

  return HMBDroplist<Contact>(
    title: 'Contact',
    selectedItem: () async => placeholder.contact,
    items: (filter) async {
      if (data.job != null && data.job!.contactId != null) {
        final contact = await DaoContact().getById(data.job!.contactId);
        return [contact!];
      } else {
        final customer = await DaoCustomer().getById(data.job!.customerId);
        return DaoContact().getByFilter(customer!, filter);
      }
    },
    format: (contact) => contact.fullname,
    onChanged: (contact) {
      placeholder.contact = contact;
      // Reset site and contact when contact changes
      assert(placeholder.onChanged != null, 'You must call listen');
      placeholder.onChanged
          ?.call(contact, ResetFields(site: true, contact: true));
    },
  );
}

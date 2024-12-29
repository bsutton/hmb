import 'package:flutter/material.dart';

import '../../../entity/contact.dart';
import '../message_template_dialog.dart';
import 'source.dart';

class DelaySource extends Source<String> {
  DelaySource() : super(name: 'delay');

  /// needs be taken from th emanager.
  Contact? contact;
  String delay = periods[0];

  static const periods = <String>[
    '10 minutes',
    '15 minutes',
    '20 minutes',
    '30 minutes',
    '45 minutes',
    '1 hour',
    '1.5 hours',
    '2 hours'
  ];

  /// Delay Period placeholder drop list
  @override
  Widget widget(MessageData data) => DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'Delay Period'),
        value: periods[0],
        items: periods
            .map((period) => DropdownMenuItem<String>(
                  value: period,
                  child: Text(period),
                ))
            .toList(),
        onChanged: (newValue) {
          delay = newValue ?? '';
        },
      );
}

// /// Contact placeholder drop list
// Widget _buildContactDroplist(ContactName placeholder, MessageData data) {
//   placeholder.setValue(data.contact);

//   return HMBDroplist<Contact>(
//     title: 'Contact',
//     selectedItem: () async => placeholder.contact,
//     items: (filter) async {
//       if (data.job != null && data.job!.contactId != null) {
//         final contact = await DaoContact().getById(data.job!.contactId);
//         return [contact!];
//       } else {
//         final customer = await DaoCustomer().getById(data.job!.customerId);
//         return DaoContact().getByFilter(customer!, filter);
//       }
//     },
//     format: (contact) => contact.fullname,
//     onChanged: (contact) {
//       placeholder.contact = contact;
//       // Reset site and contact when contact changes
//       assert(placeholder.onChanged != null, 'You must call listen');
//       placeholder.onChanged
//           ?.call(contact, ResetFields(site: true, contact: true));
//     },
//   );
// }

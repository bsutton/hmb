import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao_contact.dart';
import '../../../entity/contact.dart';
import '../../../entity/customer.dart';

class SelectBillingContactDialog extends StatefulWidget {
  const SelectBillingContactDialog({super.key, required this.customer});

  final Customer customer;

  static Future<Contact?> show(BuildContext context, Customer customer) {
    final selectedContact = June.getState(SelectedContact.new);
    selectedContact.contactId = customer.billingContactId;

    return showDialog<Contact>(
      context: context,
      builder: (context) => SelectBillingContactDialog(customer: customer),
    );
  }

  @override
  State<SelectBillingContactDialog> createState() =>
      _SelectBillingContactDialogState();
}

class _SelectBillingContactDialogState
    extends State<SelectBillingContactDialog> {
  @override
  Widget build(BuildContext context) {
    final selectedContact = June.getState(SelectedContact.new);

    return AlertDialog(
      title: const Text('Select Billing Contact'),
      content: HMBSelectContact(
        customer: widget.customer,
        selectedContact: selectedContact,
      ),
      actions: [
        HMBButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        HMBButton(
          label: 'OK',
          onPressed: () async {
            final contactId = selectedContact.contactId;
            if (contactId == null) {
              HMBToast.error('Please select a contact.');
              return;
            }
            final contact = await DaoContact().getById(contactId);
            if (contact != null) {
              Navigator.pop(context, contact);
            }
          },
        ),
      ],
    );
  }
}

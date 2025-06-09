import 'package:flutter/material.dart';

import '../../../entity/contact.dart';
import '../../../entity/customer.dart';
import '../widgets/select/select.g.dart';
import '../widgets/widgets.g.dart';

void Function(Contact? contact)? onSelected;

class SelectBillingContactDialog extends StatefulWidget {
  const SelectBillingContactDialog({
    required this.customer,
    required this.initialContact,
    required this.onSelected,
    super.key,
  });

  final Customer customer;
  final Contact? initialContact;

  final void Function(Contact? contact)? onSelected;

  // June.getState(SelectedContact.new).contactId = customer.billingContactId;
  static Future<Contact?> show(
    BuildContext context,
    Customer customer,
    Contact? contact,
    void Function(Contact? contact)? onSelected,
  ) => showDialog<Contact>(
    context: context,
    builder: (context) => SelectBillingContactDialog(
      customer: customer,
      initialContact: contact,
      onSelected: onSelected,
    ),
  );

  @override
  State<SelectBillingContactDialog> createState() =>
      _SelectBillingContactDialogState();
}

class _SelectBillingContactDialogState
    extends State<SelectBillingContactDialog> {
  @override
  void initState() {
    super.initState();
    contact = widget.initialContact;
  }

  late Contact? contact;
  // final selectedContact = June.getState(SelectedContact.new);
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Select Billing Contact'),
    content: HMBSelectContact(
      customer: widget.customer,
      initialContact: contact?.id,
      onSelected: widget.onSelected,
    ),
    actions: [
      HMBButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
      HMBButton(
        label: 'OK',
        onPressed: () {
          if (contact == null) {
            HMBToast.error('Please select a contact.');
            return;
          }
          if (contact != null && context.mounted) {
            Navigator.pop(context, contact);
          }
        },
      ),
    ],
  );
}

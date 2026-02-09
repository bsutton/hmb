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

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../dao/dao_contact.dart';
import '../../../dao/join_adaptors/join_adaptor_customer_contact.dart';
import '../../../entity/contact.dart';
import '../../../entity/customer.dart';
import '../crud/contact/edit_contact_screen.dart';
import '../widgets/widgets.g.dart';

void Function(Contact? contact)? onSelected;

class SelectBillingContactDialog extends StatefulWidget {
  final Customer customer;
  final Contact? initialContact;
  final void Function(Contact? contact)? onSelected;

  const SelectBillingContactDialog({
    required this.customer,
    required this.initialContact,
    required this.onSelected,
    super.key,
  });

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
  final _daoContact = DaoContact();
  List<Contact> _contacts = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    contact = widget.initialContact;
    unawaited(_loadContacts());
  }

  late Contact? contact;

  Future<void> _loadContacts({Contact? selected}) async {
    setState(() {
      _loading = true;
    });
    final contacts = await _daoContact.getByCustomer(widget.customer.id);
    if (!mounted) {
      return;
    }

    var nextSelection = selected ?? contact ?? widget.initialContact;
    if (nextSelection != null) {
      final index = contacts.indexWhere((c) => c.id == nextSelection!.id);
      if (index == -1) {
        _contacts = [nextSelection, ...contacts];
      } else {
        _contacts = contacts;
        nextSelection = _contacts[index];
      }
    } else {
      _contacts = contacts;
    }

    setState(() {
      contact = nextSelection;
      _loading = false;
    });
  }

  void _selectContact(Contact? selected) {
    if (selected?.id == contact?.id) {
      return;
    }
    setState(() {
      contact = selected;
    });
    widget.onSelected?.call(selected);
  }

  Future<void> _addContact() async {
    final newContact = await Navigator.push<Contact>(
      context,
      MaterialPageRoute<Contact>(
        builder: (context) => ContactEditScreen<Customer>(
          parent: widget.customer,
          daoJoin: JoinAdaptorCustomerContact(),
        ),
      ),
    );

    if (!mounted || newContact == null) {
      return;
    }

    await _loadContacts(selected: newContact);
    widget.onSelected?.call(newContact);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Select Billing Contact'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Contacts')),
              HMBButtonAdd(enabled: true, onAdd: _addContact),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _contacts.isEmpty
                ? const Text('No contacts found.')
                : RadioGroup<Contact?>(
                    groupValue: contact,
                    onChanged: _selectContact,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        final current = _contacts[index];
                        final fullName =
                            '${current.firstName} ${current.surname}'.trim();
                        final subtitle = current.emailAddress.isNotEmpty
                            ? current.emailAddress
                            : (current.mobileNumber.isNotEmpty
                                  ? current.mobileNumber
                                  : null);
                        return RadioListTile<Contact?>(
                          value: current,
                          title: Text(
                            fullName.isEmpty ? 'Unnamed contact' : fullName,
                          ),
                          subtitle: subtitle == null ? null : Text(subtitle),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    ),
    actions: [
      HMBButton(
        label: 'Cancel',
        hint: "Don't change the billing Contact",
        onPressed: () => Navigator.pop(context),
      ),
      HMBButton(
        label: 'OK',
        hint: 'Change the billing Contact to the select one',
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

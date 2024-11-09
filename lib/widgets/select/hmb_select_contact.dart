import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../crud/contact/edit_contact_screen.dart';
import '../../dao/dao_contact.dart';
import '../../dao/join_adaptors/join_adaptor_customer_contact.dart';
import '../../entity/contact.dart';
import '../../entity/customer.dart';
import '../hmb_add_button.dart';
import 'hmb_droplist.dart';

/// Allows the user to select a Primary Contact from the contacts
/// owned by a customer and associate them with another
/// entity e.g. a job.
class HMBSelectContact extends StatefulWidget {
  const HMBSelectContact(
      {required this.selectedContact,
      required this.customer,
      super.key,
      this.onSelected});

  /// The customer that owns the contact.
  final Customer? customer;
  final SelectedContact selectedContact;
  final void Function(Contact? contact)? onSelected;

  @override
  HMBSelectContactState createState() => HMBSelectContactState();
}

class HMBSelectContactState extends State<HMBSelectContact> {
  Future<Contact?> _getInitialContact() async =>
      DaoContact().getById(widget.selectedContact.contactId);

  Future<List<Contact>> _getContacts(String? filter) async =>
      DaoContact().getByCustomer(widget.customer?.id);

  void _onContactChanged(Contact? newValue) {
    setState(() {
      widget.selectedContact.contactId = newValue?.id;
    });
    widget.onSelected?.call(newValue);
  }

  Future<void> _addContact() async {
    final contact = await Navigator.push<Contact>(
      context,
      MaterialPageRoute<Contact>(
          builder: (context) => ContactEditScreen<Customer>(
              parent: widget.customer!, daoJoin: JoinAdaptorCustomerContact())),
    );
    if (contact != null) {
      setState(() {
        widget.selectedContact.contactId = contact.id;
      });
      widget.onSelected?.call(contact);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.customer == null) {
      return const Center(child: Text('Contacts: Select a customer first.'));
    } else {
      return Row(
        children: [
          Expanded(
            child: HMBDroplist<Contact>(
              title: 'Contact',
              selectedItem: _getInitialContact,
              onChanged: _onContactChanged,
              items: (filter) async => _getContacts(filter),
              format: (contact) => ' ${contact.firstName} ${contact.surname}',
              required: false,
            ),
          ),
          HMBButtonAdd(
            enabled: true,
            onPressed: _addContact,
          ),
        ],
      );
    }
  }
}

class SelectedContact extends JuneState {
  SelectedContact();

  int? contactId;
}

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao_contact.dart';
import '../../../dao/join_adaptors/join_adaptor_customer_contact.dart';
import '../../../entity/contact.dart';
import '../../../entity/customer.dart';
import '../../../ui/widgets/hmb_add_button.dart';
import '../../crud/contact/edit_contact_screen.dart';
import 'hmb_droplist.dart';

/// Allows the user to select a contact owned by a customer
/// and associate them with another entity (e.g. as billing contact).
class HMBSelectContact extends StatefulWidget {
  const HMBSelectContact({
    required this.selectedContact,
    required this.customer,
    this.onSelected,
    this.title = 'Contact',
    super.key,
  });

  /// The customer that owns the contact.
  final Customer? customer;

  /// A reference to the June state tracking the selected contact ID.
  final SelectedContact selectedContact;

  /// Called when a contact is selected.
  final void Function(Contact? contact)? onSelected;

  /// Label for the field.
  final String title;

  @override
  HMBSelectContactState createState() => HMBSelectContactState();
}

class HMBSelectContactState extends State<HMBSelectContact> {
  /// Fetch the current selected contact by ID.
  Future<Contact?> _getInitialContact() =>
      DaoContact().getById(widget.selectedContact.contactId);

  /// Fetch all contacts for the given customer.
  Future<List<Contact>> _getContacts(String? filter) =>
      DaoContact().getByCustomer(widget.customer?.id);

  /// Called when a contact is selected from the droplist.
  void _onContactChanged(Contact? newValue) {
    final newId = newValue?.id;
    if (newId != widget.selectedContact.contactId) {
      setState(() {
        widget.selectedContact.contactId = newId;
      });
      widget.onSelected?.call(newValue);
    }
  }

  /// Launches the add contact screen and updates selection if contact is added.
  Future<void> _addContact() async {
    final contact = await Navigator.push<Contact>(
      context,
      MaterialPageRoute<Contact>(
        builder:
            (context) => ContactEditScreen<Customer>(
              parent: widget.customer!,
              daoJoin: JoinAdaptorCustomerContact(),
            ),
      ),
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
              title: widget.title,
              selectedItem: _getInitialContact,
              onChanged: _onContactChanged,
              items: _getContacts,
              format: (contact) => '${contact.firstName} ${contact.surname}',
              required: false,
            ),
          ),
          HMBButtonAdd(enabled: true, onPressed: _addContact),
        ],
      );
    }
  }
}

/// State object to persist the selected contact ID across screens.
class SelectedContact extends JuneState {
  SelectedContact();

  int? contactId;
}

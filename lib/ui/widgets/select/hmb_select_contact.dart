import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

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
    required this.initialContact,
    required this.customer,
    this.onSelected,
    this.title = 'Contact',
    super.key,
  });

  /// The customer that owns the contact.
  final Customer? customer;

  final int? initialContact;

  /// Called when a contact is selected.
  final void Function(Contact? contact)? onSelected;

  /// Label for the field.
  final String title;

  @override
  HMBSelectContactState createState() => HMBSelectContactState();
}

class HMBSelectContactState extends DeferredState<HMBSelectContact> {
  Contact? contact;

  @override
  Future<void> asyncInitState() async {
    contact = await DaoContact().getById(widget.initialContact);
  }

  /// Fetch all contacts for the given customer.
  Future<List<Contact>> _getContacts(String? filter) =>
      DaoContact().getByCustomer(widget.customer?.id);

  /// Called when a contact is selected from the droplist.
  void _onContactChanged(Contact? newValue) {
    final newId = newValue?.id;
    if (newId != contact?.id) {
      setState(() {
        contact = newValue;
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
        this.contact = contact;
      });
      widget.onSelected?.call(contact);
    }
  }

  @override
  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) {
      if (widget.customer == null) {
        return const Center(child: Text('Contacts: Select a customer first.'));
      } else {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: HMBDroplist<Contact>(
                title: widget.title,
                selectedItem: () async => contact,
                onChanged: _onContactChanged,
                items: _getContacts,
                format: (contact) => '${contact.firstName} ${contact.surname}',
                required: false,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(
                top: 16,
              ), // tweak this to align visually
              child: HMBButtonAdd(enabled: true, onPressed: _addContact),
            ),
          ],
        );
      }
    },
  );
}

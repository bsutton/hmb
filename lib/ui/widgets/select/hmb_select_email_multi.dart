import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/widgets.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../widgets.g.dart';
import 'hmb_droplist_multi.dart';

class HMBSelectEmailMulti extends StatefulWidget {
  final Job job;
  final void Function(List<String>) onChanged;

  /// One or more email addresses that should be pre-selected.
  /// Matching is case-insensitive and whitespace-insensitive.
  final List<String> initialEmails;

  const HMBSelectEmailMulti({
    required this.job,
    required this.onChanged,
    this.initialEmails = const [],
    super.key,
  });

  @override
  State<HMBSelectEmailMulti> createState() => _HMBSelectEmailMultiState();
}

class _HMBSelectEmailMultiState extends DeferredState<HMBSelectEmailMulti> {
  final preSelected = <ContactAndEmail>[];

  @override
  Future<void> asyncInitState() async {
    if (widget.initialEmails.isEmpty) {
      return;
    }

    final all = await ContactAndEmail.fromJob(widget.job, null);

    // Normalise for case/whitespace to be forgiving.
    String norm(String s) => s.trim().toLowerCase();
    final wanted = widget.initialEmails
        .map(norm)
        .where((e) => e.isNotEmpty)
        .toSet();

    // Keep the original order from `all`, include any whose email matches.
    for (final item in all) {
      if (wanted.contains(norm(item.email))) {
        preSelected.add(item);
      }
    }
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) =>
        HMBDroplistMultiSelect<ContactAndEmail>(
          initialItems: () async => preSelected,

          // All available items, filtered by the user's query.
          items: (filter) => ContactAndEmail.fromJob(widget.job, filter),
          format: (contactEmail) =>
              '${contactEmail.contact.fullname}\n${contactEmail.email}',
          onChanged: (selectedContacts) {
            widget.onChanged(
              selectedContacts.map((contact) => contact.email).toList(),
            );
          },
          title: 'To',
          backgroundColor: SurfaceElevation.e4.color,
          required: false,
        ).help('Select the Email Addresses.', '''
The selected email addresses will be added to the email "To" list.'''),
  );
}

@immutable
class ContactAndEmail {
  final Contact contact;
  final String email;

  const ContactAndEmail._internal(this.contact, this.email);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ContactAndEmail &&
        other.contact.id == contact.id &&
        other.email == email;
  }

  @override
  int get hashCode => Object.hash(contact.id, email);

  /// Returns all [ContactAndEmail] selectable for the given [job].
  /// If [filter] is provided, performs a case-insensitive contains match
  /// against contact fullname and email.
  static Future<List<ContactAndEmail>> fromJob(Job job, String? filter) async {
    final list = <ContactAndEmail>[];

    final contacts = await DaoContact().getByJob(job.id);
    for (final contact in contacts) {
      // Extract all email addresses from each contact.
      if (Strings.isNotBlank(contact.emailAddress)) {
        list.add(ContactAndEmail._internal(contact, contact.emailAddress));
      }
      if (Strings.isNotBlank(contact.alternateEmail)) {
        list.add(ContactAndEmail._internal(contact, contact.alternateEmail!));
      }
    }

    // Also include the system/organisation email as a selectable option.
    final system = await DaoSystem().get();
    if (Strings.isNotBlank(system.emailAddress)) {
      // Create a fake contact so we can give the user the option to
      // select their own email address.
      list.add(
        ContactAndEmail._internal(
          Contact.forInsert(
            firstName: system.firstname ?? '',
            surname: system.surname ?? '',
            mobileNumber: '',
            landLine: '',
            officeNumber: '',
            emailAddress: system.emailAddress!,
          ),
          system.emailAddress!,
        ),
      );
    }

    if (Strings.isBlank(filter)) {
      return list;
    }

    final q = filter!.trim().toLowerCase();
    return list
        .where(
          (contactAndEmail) =>
              contactAndEmail.contact.fullname.toLowerCase().contains(q) ||
              contactAndEmail.email.toLowerCase().contains(q),
        )
        .toList();
  }
}

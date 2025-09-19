import 'package:flutter/widgets.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../widgets.g.dart';
import 'hmb_droplist_multi.dart';

class HMBSelectEmailMulti extends StatelessWidget {
  final Job job;
  final void Function(List<String>) onChanged;

  const HMBSelectEmailMulti({
    required this.job,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) =>
      HMBDroplistMultiSelect<ContactAndEmail>(
        initialItems: () async => [],
        items: (filter) => ContactAndEmail.fromJob(job, filter),
        format: (contactEmail) =>
            '${contactEmail.contact.fullname}\n${contactEmail.email}',
        onChanged: (selectedContacts) {
          onChanged(selectedContacts.map((contact) => contact.email).toList());
        },
        title: 'To',
        backgroundColor: SurfaceElevation.e4.color,
        required: false,
      ).help('Select the Email Addresses.', '''
The selected email addresses will be added to the email To list.. ''');
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

  static Future<List<ContactAndEmail>> fromJob(Job job, String? filter) async {
    final list = <ContactAndEmail>[];

    final contacts = await DaoContact().getByJob(job.id);
    for (final contact in contacts) {
      // extract all email addresses from each contact.
      if (Strings.isNotBlank(contact.emailAddress)) {
        list.add(ContactAndEmail._internal(contact, contact.emailAddress));
      }
      if (Strings.isNotBlank(contact.alternateEmail)) {
        list.add(ContactAndEmail._internal(contact, contact.alternateEmail!));
      }
    }

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
    return list
        .where(
          (contactAndEmail) =>
              contactAndEmail.contact.fullname.contains(filter!) ||
              contactAndEmail.email.contains(filter),
        )
        .toList();
  }
}

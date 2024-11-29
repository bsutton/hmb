import 'package:flutter/material.dart';

import '../../../entity/contact.dart';

class ContactText extends StatelessWidget {
  const ContactText({required this.label, required this.contact, super.key});
  final String label;
  final Contact? contact;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            if (contact != null) Text(label),
            if (contact != null)
              Text('${contact?.firstName} ${contact?.surname}')
          ],
        ),
      );
}

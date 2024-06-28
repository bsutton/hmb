import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../util/plus_space.dart';
import 'mail_to_icon.dart';

class HMBEmailText extends StatelessWidget {
  const HMBEmailText({required this.email, this.label, super.key});
  final String? label;
  final String? email;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (Strings.isNotBlank(email))
            Text('${plusSpace(label)} ${email ?? ''}'),
          if (Strings.isNotBlank(email)) MailToIcon(email)
        ],
      );
}

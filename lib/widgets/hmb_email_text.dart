import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../dao/dao_contact.dart';
import '../entity/job.dart';
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

class HMBJobEmailText extends StatelessWidget {
  const HMBJobEmailText({required this.job, this.label, super.key});
  final String? label;
  final Job job;

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
      // ignore: discarded_futures
      future: DaoContact().getForJob(job.id),
      builder: (context, contact) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (Strings.isNotBlank(contact?.emailAddress))
                Text('${plusSpace(label)} ${contact?.emailAddress ?? ''}'),
              if (Strings.isNotBlank(contact?.emailAddress))
                MailToIcon(contact?.emailAddress)
            ],
          ));
}

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_contact.dart';
import '../../entity/job.dart';
import '../../util/plus_space.dart';
import '../layout/hmb_placeholder.dart';
import '../mail_to_icon.dart';

class HMBEmailText extends StatelessWidget {
  const HMBEmailText({required this.email, this.label, super.key});
  final String? label;
  final String? email;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (Strings.isNotBlank(email))
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${plusSpace(label)} ${email ?? ''}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          if (Strings.isNotBlank(email))
            Align(
              alignment: Alignment.centerRight,
              child: MailToIcon(email),
            ),
        ],
      );
}

class HMBJobEmailText extends StatelessWidget {
  const HMBJobEmailText({required this.job, this.label, super.key});
  final String? label;
  final Job job;

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
      waitingBuilder: (_) => const HMBPlaceHolder(height: 40),
      // ignore: discarded_futures
      future: DaoContact().getPrimaryForJob(job.id),
      builder: (context, contact) =>
          HMBEmailText(email: contact?.emailAddress, label: label));
}

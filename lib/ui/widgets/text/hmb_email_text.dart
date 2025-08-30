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

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_contact.dart';
import '../../../entity/job.dart';
import '../../../util/dart/plus_space.dart';
import '../../../util/flutter/hmb_theme.dart';
import '../hmb_mail_to_icon.dart';
import '../layout/hmb_placeholder.dart';

class HMBEmailText extends StatelessWidget {
  final String? label;
  final String? email;

  const HMBEmailText({required this.email, this.label, super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (Strings.isNotBlank(email))
        Flexible(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${plusSpace(label)}${email ?? ''}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: HMBColors.textPrimary),
            ),
          ),
        ),
      if (Strings.isNotBlank(email))
        Align(alignment: Alignment.centerRight, child: HMBMailToIcon(email)),
    ],
  );
}

class HMBJobEmailText extends StatelessWidget {
  final String? label;
  final Job job;

  const HMBJobEmailText({required this.job, this.label, super.key});

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
    waitingBuilder: (_) => const HMBPlaceHolder(height: 40),
    // ignore: discarded_futures
    future: DaoContact().getPrimaryForJob(job.id),
    builder: (context, contact) =>
        HMBEmailText(email: contact?.emailAddress, label: label),
  );
}

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../dao/dao_contact.dart';
import '../entity/job.dart';
import '../util/plus_space.dart';
import 'dial_widget.dart';

/// Displays the label and phoneNum.
/// If the phoneNum is null then we display nothing.
class HMBPhoneText extends StatelessWidget {
  const HMBPhoneText({required this.phoneNo, this.label, super.key});
  final String? label;
  final String? phoneNo;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (Strings.isNotBlank(phoneNo)) Text('${plusSpace(label)} $phoneNo'),
          if (Strings.isNotBlank(phoneNo)) DialWidget(phoneNo!)
        ],
      );
}

/// Displays the label and phoneNum.
/// If the phoneNum is null then we display nothing.
class HMBJobPhoneText extends StatelessWidget {
  const HMBJobPhoneText({required this.job, this.label, super.key});
  final String? label;
  final Job job;

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
      // ignore: discarded_futures
      future: DaoContact().getById(job.contactId),
      builder: (context, contact) {
        final phoneNo = contact?.preferredPhone();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (Strings.isNotBlank(phoneNo))
              Text('${plusSpace(label)} $phoneNo'),
            if (Strings.isNotBlank(phoneNo)) DialWidget(phoneNo!)
          ],
        );
      });
}

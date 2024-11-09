import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_contact.dart';
import '../../entity/job.dart';
import '../../util/plus_space.dart';
import '../dial_widget.dart';
import '../layout/hmb_placeholder.dart';

/// Displays the label and phoneNum.
/// If the phoneNum is null then we display nothing.

class HMBPhoneText extends StatelessWidget {
  const HMBPhoneText({required this.phoneNo, this.label, super.key});
  final String? label;
  final String? phoneNo;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (Strings.isNotBlank(phoneNo))
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${plusSpace(label)} $phoneNo',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          if (Strings.isNotBlank(phoneNo))
            Align(
              alignment: Alignment.centerRight,
              child: DialWidget(phoneNo!),
            ),
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
      waitingBuilder: (_) => const HMBPlaceHolder(height: 40),
      // ignore: discarded_futures
      future: DaoContact().getById(job.contactId),
      builder: (context, contact) {
        final phoneNo = contact?.bestPhone;
        return HMBPhoneText(
          phoneNo: phoneNo,
        );
      });
}

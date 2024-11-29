import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_contact.dart';
import '../../../dao/dao_customer.dart';
import '../../../dao/dao_site.dart';
import '../../../entity/job.dart';
import '../../../ui/widgets/dial_widget.dart';
import '../../../util/plus_space.dart';
import '../../dialog/message_template_dialog.dart';
import '../layout/hmb_placeholder.dart';

/// Displays the label and phoneNum.
/// If the phoneNum is null then we display nothing.

class HMBPhoneText extends StatelessWidget {
  const HMBPhoneText(
      {required this.phoneNo,
      required this.messageData,
      this.label,
      super.key});
  final String? label;
  final String? phoneNo;
  final MessageData messageData;

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
              child: DialWidget(phoneNo!, messageData: messageData),
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
  Widget build(BuildContext context) => FutureBuilderEx<MessageData>(
      waitingBuilder: (_) => const HMBPlaceHolder(height: 40),
      // ignore: discarded_futures
      future: getData(job),
      builder: (context, data) {
        final phoneNo = data!.contact?.bestPhone;
        return HMBPhoneText(
          phoneNo: phoneNo,
          messageData: data,
        );
      });

  Future<MessageData> getData(Job job) async {
    final contact = await DaoContact().getById(job.contactId);
    final site = await DaoSite().getById(job.siteId);
    final customer = await DaoCustomer().getById(job.customerId);

    return MessageData(
        job: job, contact: contact, site: site, customer: customer);
  }
}

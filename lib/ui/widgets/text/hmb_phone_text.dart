/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_contact.dart';
import '../../../dao/dao_customer.dart';
import '../../../dao/dao_site.dart';
import '../../../entity/job.dart';
import '../../../util/hmb_theme.dart';
import '../../../util/plus_space.dart';
import '../../dialog/source_context.dart';
import '../hmb_phone_icon.dart';
import '../layout/hmb_placeholder.dart';

/// Displays the label and phoneNum.
/// If the phoneNum is null then we display nothing.

class HMBPhoneText extends StatelessWidget {
  const HMBPhoneText({
    required this.phoneNo,
    required this.sourceContext,
    this.label,
    super.key,
  });
  final String? label;
  final String? phoneNo;
  final SourceContext sourceContext;

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
              style: const TextStyle(color: HMBColors.textPrimary),
            ),
          ),
        ),
      if (Strings.isNotBlank(phoneNo))
        Align(
          alignment: Alignment.centerRight,
          child: HMBPhoneIcon(phoneNo!, sourceContext: sourceContext),
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
  Widget build(BuildContext context) => FutureBuilderEx<SourceContext>(
    waitingBuilder: (_) => const HMBPlaceHolder(height: 40),
    // ignore: discarded_futures
    future: getData(job),
    builder: (context, sourceContext) {
      final phoneNo = sourceContext!.contact?.bestPhone;
      return HMBPhoneText(phoneNo: phoneNo, sourceContext: sourceContext);
    },
  );

  Future<SourceContext> getData(Job job) async {
    final contact = await DaoContact().getById(job.contactId);
    final site = await DaoSite().getById(job.siteId);
    final customer = await DaoCustomer().getById(job.customerId);

    return SourceContext(
      job: job,
      contact: contact,
      site: site,
      customer: customer,
    );
  }
}

/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/date_time_ex.dart';
import '../../../util/format.dart';
import '../../../util/local_date.dart';
import '../../../util/rich_text_helper.dart';
import '../../widgets/surface.dart';
import '../../widgets/text/hmb_email_text.dart';
import '../../widgets/text/hmb_phone_text.dart';
import '../../widgets/text/hmb_site_text.dart';
import '../../widgets/text/hmb_text.dart';
import '../../widgets/text/hmb_text_block.dart';
import '../../widgets/text/hmb_text_themes.dart';
import 'mini_job_dashboard.dart';

class ListJobCard extends StatefulWidget {
  const ListJobCard({required this.job, super.key});

  final Job job;

  @override
  // ignore: library_private_types_in_public_api
  _ListJobCardState createState() => _ListJobCardState();
}

class _ListJobCardState extends DeferredState<ListJobCard> {
  late Job job;
  late final JobActivity? nextActivity;
  late final Customer? customer;

  @override
  Future<void> asyncInitState() async {
    job = widget.job;
    nextActivity = await DaoJobActivity().getNextActivityByJob(job.id);
    customer = await DaoCustomer().getById(job.customerId);
  }

  @override
  void didUpdateWidget(ListJobCard old) {
    if (job != widget.job) {
      job = widget.job;
    }
    super.didUpdateWidget(old);
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => Surface(
      padding: EdgeInsets.zero,
      elevation: SurfaceElevation.e6,
      child: _buildDetails(customer, job.status),
    ),
  );

  Widget _buildDetails(Customer? customer, JobStatus? jobStatus) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,

    children: [
      HMBCardHeading(customer?.name ?? 'Not Set'),
      const SizedBox(height: 8),
      _buildContactPoints(),
      HMBJobSiteText(label: '', job: job),
      const SizedBox(height: 8),
      HMBText('''
Job #${job.id} Status: ${jobStatus?.name ?? "Status Unknown"}'''),
      const SizedBox(height: 8),
      _buildNextActivity(),
      const SizedBox(height: 8),
      const HMBText('Description:', bold: true),
      HMBTextBlock(RichTextHelper.toPlainText(job.description)),
      const SizedBox(height: 8),
      MiniJobDashboard(job: job),
    ],
  );

  Widget _buildNextActivity() {
    String activity;
    Color textColor;
    if (nextActivity == null) {
      activity = 'Not Scheduled';
      textColor = Colors.red;
    } else if (nextActivity!.start.toLocalDate() == LocalDate.today()) {
      activity = formatTime(nextActivity!.start, 'h:mm a');
      textColor = Colors.orange;
    } else {
      activity = formatDateTime(nextActivity!.start);
      textColor = Colors.white;
    }
    return HMBText('Next Activity: $activity', color: textColor);
  }

  Widget _buildContactPoints() => LayoutBuilder(
    builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: isMobile
            ? Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  HMBJobPhoneText(job: job),
                  HMBJobEmailText(job: job),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  HMBJobPhoneText(job: job),
                  Expanded(child: HMBJobEmailText(job: job)),
                ],
              ),
      );
    },
  );
}

class InvoiceScreenArguments {
  const InvoiceScreenArguments({required this.job});

  final Job job;
}

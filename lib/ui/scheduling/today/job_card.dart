import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../../crud/job/full_page_list_job_card.dart' show FullPageListJobCard;
import '../../dialog/source_context.dart';
import '../../widgets/text/text.g.dart';
import '../../widgets/widgets.g.dart';
import 'today_page.dart';

class JobCard extends StatelessWidget {
  const JobCard(this.jobAndActivity, {super.key});
  final JobAndActivity jobAndActivity;

  @override
  Widget build(BuildContext context) {
    final jobName = jobAndActivity.jobAndCustomer.job.summary;
    final note = jobAndActivity.jobActivity.notes;
    var displayText = jobName;
    if (note != null && note.trim().isNotEmpty) {
      final firstLine = note.trim().split('\n').first;
      displayText = '$jobName / $firstLine';
    }

    return Card(
      color: SurfaceElevation.e6.color,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4, right: 8),
        child: Align(
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wrap the first two rows in a Row so we can have
              //a two-row column at the end.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Column with job activity and customer name.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                displayText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            HMBTextLine(
                              jobAndActivity.jobAndCustomer.customer.name,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Right: Column spanning two rows with the job link.
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HMBLinkInternal(
                        label: 'Job: #${jobAndActivity.jobAndCustomer.job.id}',
                        navigateTo: () async => FullPageListJobCard(
                          jobAndActivity.jobAndCustomer.job,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Action icons row.
              Row(
                children: [
                  HMBMapIcon(
                    jobAndActivity.jobAndCustomer.site,
                    onMapClicked: () async {
                      await DaoJob().markActive(
                        jobAndActivity.jobAndCustomer.job.id,
                      );
                    },
                  ),
                  HMBPhoneIcon(
                    jobAndActivity.jobAndCustomer.bestPhoneNo ?? '',
                    sourceContext: SourceContext(
                      job: jobAndActivity.jobAndCustomer.job,
                      customer: jobAndActivity.jobAndCustomer.customer,
                    ),
                  ),
                  HMBMailToIcon(jobAndActivity.jobAndCustomer.bestEmailAddress),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao_job.dart';
import '../../../dao/dao_job_status.dart';
import '../../../entity/job.dart';
import '../../../entity/job_status_enum.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/surface.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'edit_job_screen.dart';
import 'job_card.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({super.key});

  static const pageTitle = 'Jobs';

  @override
  // ignore: library_private_types_in_public_api
  _JobListScreenState createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  @override
  Widget build(BuildContext context) => Surface(
    elevation: SurfaceElevation.e0,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            HMBButtonPrimary(
              hint: June.getState(FilterState.new)._showOnHoldAndFinalised
                  ? 'Show Jobs active Jobs'
                  : 'Show Jobs that are on hold or have been finalised.',
              onPressed: () {
                setState(() {
                  June.getState(FilterState.new).toggle();
                });
              },
              label: June.getState(FilterState.new)._showOnHoldAndFinalised
                  ? 'Show PreStart & Progressing'
                  : 'Show OnHold & Finalised',
            ),
          ],
        ),
        Flexible(
          child: JuneBuilder(
            FilterState.new,
            builder: (context) => EntityListScreen<Job>(
              key: ValueKey(
                June.getState(FilterState.new)._showOnHoldAndFinalised,
              ),
              dao: DaoJob(),
              pageTitle: JobListScreen.pageTitle,
              onEdit: (job) => JobEditScreen(job: job),
              fetchList: _fetchJobs,
              title: (job) => HMBCardTitle(job.summary),
              cardHeight: 700,
              background: (job) async =>
                  (await DaoJobStatus().getById(
                    job.jobStatusId,
                  ))?.getColour() ??
                  Colors.green,
              details: (job) => JobCard(job: job, key: ValueKey(job.hashCode)),
            ),
          ),
        ),
      ],
    ),
  );

  Future<List<Job>> _fetchJobs(String? filter) async {
    final jobs = await DaoJob().getByFilter(filter);
    final selected = <Job>[];
    for (final job in jobs) {
      final jobStatus = await DaoJobStatus().getById(job.jobStatusId);
      final status = jobStatus?.statusEnum;
      if (June.getState(FilterState.new)._showOnHoldAndFinalised) {
        if (status == JobStatusEnum.onHold ||
            status == JobStatusEnum.finalised) {
          selected.add(job);
        }
      } else {
        if (status == JobStatusEnum.preStart ||
            status == JobStatusEnum.progressing) {
          selected.add(job);
        }
      }
    }
    return selected;
  }
}

class FilterState extends JuneState {
  var _showOnHoldAndFinalised = false;

  void toggle() {
    _showOnHoldAndFinalised = !_showOnHoldAndFinalised;
    setState();
  }
}

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../dao/dao_job.dart';
import '../../dao/dao_job_status.dart';
import '../../entity/job.dart';
import '../../entity/job_status_enum.dart';
import '../../widgets/hmb_text_themes.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'job_card.dart';
import 'edit_job_screen.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _JobListScreenState createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    June.getState(FilterState.new).toggle();
                  });
                },
                child: Text(
                    June.getState(FilterState.new).showOnHoldAndFinalised
                        ? 'Show PreStart & Progressing'
                        : 'Show OnHold & Finalised'),
              ),
            ],
          ),
          Flexible(
            child: JuneBuilder(FilterState.new,
                builder: (context) => EntityListScreen<Job>(
                      key: ValueKey(June.getState(FilterState.new)
                          .showOnHoldAndFinalised),
                      dao: DaoJob(),
                      pageTitle: 'Jobs',
                      onEdit: (job) => JobEditScreen(job: job),
                      fetchList: (filter) async => _fetchJobs(filter),
                      title: (job) => HMBTextHeadline(job.summary),
                      background: (job) async =>
                          (await DaoJobStatus().getById(job.jobStatusId))
                              ?.getColour() ??
                          Colors.white,
                      details: (job) => JobCard(job: job),
                    )),
          ),
        ],
      );

  Future<List<Job>> _fetchJobs(String? filter) async {
    final jobs = await DaoJob().getByFilter(filter);
    final selected = <Job>[];
    for (final job in jobs) {
      final jobStatus = await DaoJobStatus().getById(job.jobStatusId);
      final status = jobStatus?.statusEnum;
      if (June.getState(FilterState.new).showOnHoldAndFinalised) {
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
  bool showOnHoldAndFinalised = false;

  void toggle() {
    showOnHoldAndFinalised = !showOnHoldAndFinalised;
    refresh();
  }
}

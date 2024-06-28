import 'package:flutter/material.dart';

import '../../dao/dao_job.dart';
import '../../dao/dao_job_status.dart';
import '../../entity/job.dart';
import '../base_full_screen/entity_list_screen.dart';
import 'job_card.dart';
import 'job_edit_screen.dart';

class JobListScreen extends StatelessWidget {
  const JobListScreen({super.key});

  @override
  Widget build(BuildContext context) => EntityListScreen<Job>(
        dao: DaoJob(),
        pageTitle: 'Jobs',
        onEdit: (job) => JobEditScreen(job: job),
        fetchList: (filter) async => DaoJob().getByFilter(filter),
        title: (job) => Text(
          job.summary,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        background: (job) async =>
            (await DaoJobStatus().getById(job.jobStatusId))?.getColour() ??
            Colors.white,
        details: (entity) {
          final job = entity;

          return JobCard(job: job);
        },
      );
}

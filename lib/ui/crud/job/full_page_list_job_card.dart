import 'package:flutter/material.dart';

import '../../../entity/job.dart';
import '../../widgets/layout/hmb_full_page_child_screen.dart';
import '../../widgets/layout/hmb_padding.dart';
import 'list_job_card.dart';

class FullPageListJobCard extends StatelessWidget {
  final Job job;

  const FullPageListJobCard(this.job, {super.key});

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Job',
    child: HMBPadding(child: ListJobCard(job: job)),
  );
}

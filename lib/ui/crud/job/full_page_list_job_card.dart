import 'dart:async';

import 'package:flutter/material.dart';

import '../../../dao/dao_job.dart';
import '../../../entity/job.dart';
import '../../widgets/layout/hmb_full_page_child_screen.dart';
import 'list_job_card.dart';

class FullPageListJobCard extends StatefulWidget {
  final Job job;

  const FullPageListJobCard(this.job, {super.key});

  @override
  State<FullPageListJobCard> createState() => _FullPageListJobCardState();
}

class _FullPageListJobCardState extends State<FullPageListJobCard> {
  @override
  void initState() {
    super.initState();
    // Opening a job details card should make that job the active job.
    unawaited(DaoJob().markActive(widget.job.id));
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Job',
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: ListJobCard(job: widget.job),
    ),
  );
}

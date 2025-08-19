/*
 Copyright © OnePub IP Pty Ltd.
 All Rights Reserved.
*/

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../crud/job/edit_job_screen.dart';
import '../hmb_add_button.dart';
import 'hmb_droplist.dart';

/// Allows the user to select a Job from the database.
/// You can optionally preselect an initial job and handle selection changes.
class HMBSelectJob extends StatefulWidget {
  const HMBSelectJob({
    required this.selectedJobId,
    super.key,
    this.onSelected,
    this.title = 'Job',
    this.items,
    this.required = false,
  });

  final SelectedJob selectedJobId;
  final void Function(Job? job)? onSelected;
  final Future<List<Job>> Function(String? filter)? items;
  final bool required;
  final String title;

  @override
  State<HMBSelectJob> createState() => _HMBSelectJobState();
}

class JobAndCustomer {
  JobAndCustomer(this.job, this.customer);
  Job? job;
  Customer? customer;
}

class _HMBSelectJobState extends State<HMBSelectJob> {
  Future<JobAndCustomer?> _getInitialJob() async {
    final job = await DaoJob().getById(widget.selectedJobId.jobId);
    if (job == null) {
      return null;
    }

    final customer = await DaoCustomer().getById(job.customerId);

    return JobAndCustomer(job, customer);
  }

  Future<List<JobAndCustomer>> _getJobs(String? filter) async {
    List<Job>? jobs;
    if (widget.items != null) {
      jobs = await widget.items?.call(filter);
    } else {
      jobs = await DaoJob().getActiveJobs(filter);
    }

    final jc = <JobAndCustomer>[];

    for (final job in jobs!) {
      final customer = await DaoCustomer().getById(job.customerId);

      jc.add(JobAndCustomer(job, customer));
    }
    return jc;
  }

  void _onJobChanged(JobAndCustomer? jc) {
    setState(() {
      widget.selectedJobId.jobId = jc?.job?.id;
    });
    widget.onSelected?.call(jc?.job);
  }

  Future<void> _addJob() async {
    final job = await Navigator.push<Job>(
      context,
      MaterialPageRoute<Job>(builder: (context) => const JobEditScreen()),
    );
    if (job != null) {
      setState(() {
        widget.selectedJobId.jobId = job.id;
      });
      widget.onSelected?.call(job);
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: HMBDroplist<JobAndCustomer>(
          title: widget.title,
          selectedItem: _getInitialJob,
          onChanged: _onJobChanged,
          items: _getJobs,
          format: (jc) => '${jc.job!.summary}\n${jc.customer?.name?? ''}',
          required: widget.required,
        ),
      ),
      HMBButtonAdd(enabled: true, onAdd: _addJob),
    ],
  );
}

class SelectedJob extends JuneState {
  SelectedJob();

  int? _jobId;
  int? get jobId => _jobId;

  set jobId(int? value) {
    _jobId = value;
    setState();
  }
}

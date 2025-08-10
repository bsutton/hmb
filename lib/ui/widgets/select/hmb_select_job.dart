/*
 Copyright © OnePub IP Pty Ltd.
 All Rights Reserved.
*/

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao_job.dart';
import '../../../entity/job.dart';
import '../../crud/job/edit_job_screen.dart';
import '../hmb_add_button.dart';
import 'hmb_droplist.dart';

/// Allows the user to select a Job from the database.
/// You can optionally preselect an initial job and handle selection changes.
class HMBSelectJob extends StatefulWidget {
  const HMBSelectJob({required this.selectedJobId, super.key, this.onSelected, this.required = false});

  final SelectedJob selectedJobId;
  final void Function(Job? job)? onSelected;
  final bool required;

  @override
  State<HMBSelectJob> createState() => _HMBSelectJobState();
}

class _HMBSelectJobState extends State<HMBSelectJob> {
  Future<Job?> _getInitialJob() => DaoJob().getById(widget.selectedJobId.jobId);

  Future<List<Job>> _getJobs(String? filter) => DaoJob().getByFilter(filter);

  void _onJobChanged(Job? newValue) {
    setState(() {
      widget.selectedJobId.jobId = newValue?.id;
    });
    widget.onSelected?.call(newValue);
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
        child: HMBDroplist<Job>(
          title: 'Job',
          selectedItem: _getInitialJob,
          onChanged: _onJobChanged,
          items: _getJobs,
          format: (job) => job.summary,
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

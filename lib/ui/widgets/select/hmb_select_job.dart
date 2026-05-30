/*
 Copyright © OnePub IP Pty Ltd.
 All Rights Reserved.
*/

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../crud/job/job_creator.dart';
import '../layout/layout.g.dart';
import 'hmb_droplist.dart';

/// Allows the user to select a Job from the database.
/// You can optionally preselect an initial job and handle selection changes.
class HMBSelectJob extends StatefulWidget {
  final SelectedJob selectedJob;
  final void Function(Job? job)? onSelected;
  final Future<List<Job>> Function(String? filter)? items;
  final bool required;
  final String title;
  final bool showAdd;

  const HMBSelectJob({
    required this.selectedJob,
    super.key,
    this.onSelected,
    this.title = 'Job',
    this.items,
    this.required = false,
    this.showAdd = true,
  });

  @override
  State<HMBSelectJob> createState() => _HMBSelectJobState();
}

class JobAndCustomer {
  Job? job;
  Customer? customer;

  JobAndCustomer(this.job, this.customer);
}

class _HMBSelectJobState extends State<HMBSelectJob> {
  var _showActiveJobs = true;
  var _showInactiveJobs = false;

  Future<JobAndCustomer?> _getInitialJob() async {
    final job = await DaoJob().getById(widget.selectedJob.jobId);
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
      final allJobs = await DaoJob().getByFilter(filter);
      jobs = allJobs.where((job) {
        final active = _isActiveJob(job);
        return _showActiveJobs && active || _showInactiveJobs && !active;
      }).toList();
    }

    final jc = <JobAndCustomer>[];

    for (final job in jobs!) {
      final customer = await DaoCustomer().getById(job.customerId);

      jc.add(JobAndCustomer(job, customer));
    }
    return jc;
  }

  bool _isActiveJob(Job job) =>
      job.status != JobStatus.rejected &&
      job.status != JobStatus.onHold &&
      job.status != JobStatus.awaitingPayment &&
      job.status != JobStatus.completed &&
      job.status != JobStatus.toBeBilled;

  void _onJobChanged(JobAndCustomer? jc) {
    setState(() {
      widget.selectedJob.jobId = jc?.job?.id;
    });
    widget.onSelected?.call(jc?.job);
  }

  Future<void> _addJob() async {
    final job = await JobCreator.show(context);
    if (job != null) {
      setState(() {
        widget.selectedJob.jobId = job.id;
      });
      widget.onSelected?.call(job);
    }
  }

  @override
  Widget build(BuildContext context) => HMBDroplist<JobAndCustomer>(
    title: widget.title,
    selectedItem: _getInitialJob,
    onChanged: _onJobChanged,
    items: _getJobs,
    format: (jc) => '${jc.job!.summary}\n${jc.customer?.name ?? ''}',
    required: widget.required,
    onAdd: widget.showAdd ? _addJob : null,
    filterSheetBuilder: widget.items == null ? _buildFilterSheet : null,
    onFilterReset: widget.items == null ? _resetFilters : null,
    isFilterActive: widget.items == null ? _isFilterActive : null,
  );

  bool _isFilterActive() => !_showActiveJobs || !_showInactiveJobs;

  void _resetFilters() {
    _showActiveJobs = true;
    _showInactiveJobs = false;
    setState(() {});
  }

  Widget _buildFilterSheet(BuildContext context, VoidCallback onChange) =>
      StatefulBuilder(
        builder: (context, setSheetState) => HMBColumn(
          children: [
            CheckboxListTile(
              title: const Text('Show Active Jobs'),
              value: _showActiveJobs,
              onChanged: (selected) {
                if (selected == null || !selected && !_showInactiveJobs) {
                  return;
                }
                setState(() => _showActiveJobs = selected);
                setSheetState(() {});
                onChange();
              },
            ),
            CheckboxListTile(
              title: const Text('Show Inactive Jobs'),
              value: _showInactiveJobs,
              onChanged: (selected) {
                if (selected == null || !selected && !_showActiveJobs) {
                  return;
                }
                setState(() => _showInactiveJobs = selected);
                setSheetState(() {});
                onChange();
              },
            ),
          ],
        ),
      );
}

class SelectedJob extends JuneState {
  int? _jobId;

  SelectedJob();

  int? get jobId => _jobId;

  set jobId(int? value) {
    _jobId = value;
    setState();
  }
}

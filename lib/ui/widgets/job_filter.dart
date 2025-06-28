import 'dart:async';

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../dao/dao_job.dart';
import '../../entity/job.dart';
import 'select/hmb_droplist_multi.dart';

class JobFilterWidget extends StatefulWidget {
  const JobFilterWidget({required this.onJobSelectionChanged, super.key});

  final ValueChanged<List<Job>> onJobSelectionChanged;

  @override
  State<JobFilterWidget> createState() => _JobFilterWidgetState();
}

class _JobFilterWidgetState extends State<JobFilterWidget> {
  var _filterLastActive = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDefaultJob());
  }

  Future<void> _loadDefaultJob() async {
    final lastActiveJob = await DaoJob().getLastActiveJob();
    if (lastActiveJob != null) {
      setState(() {
        June.getState(SelectedJobs.new).reset([lastActiveJob]);
      });
      widget.onJobSelectionChanged(June.getState(SelectedJobs.new).selected);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CheckboxListTile(
        title: const Text('Filter by Last Active Job'),
        value: _filterLastActive,
        onChanged: (value) async {
          setState(() {
            _filterLastActive = value ?? false;
          });
          if (_filterLastActive) {
            await _loadDefaultJob();
          }
        },
      ),
      HMBDroplistMultiSelect<Job>(
        title: 'Select Jobs',
        initialItems: () async => June.getState(SelectedJobs.new).selected,
        // ignore: discarded_futures
        items: (filter) => DaoJob().getByFilter(filter),
        format: (job) => job.summary,
        onChanged: (job) {
          setState(() {
            June.getState(SelectedJobs.new).reset(job);
          });
          widget.onJobSelectionChanged(
            June.getState(SelectedJobs.new).selected,
          );
        },
      ),
    ],
  );
}

class SelectedJobs extends JuneState {
  final selected = <Job>[];

  void reset(List<Job> jobs) {
    selected
      ..clear()
      ..addAll(jobs);
    setState();
  }
}

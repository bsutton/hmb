import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../../dao/_index.g.dart';
import '../../../../entity/_index.g.dart';
import '../../../widgets/async_state.dart';
import 'job_card.dart'; // The JobCard from previous snippet

class JobEstimatesListScreen extends StatefulWidget {
  const JobEstimatesListScreen({super.key});

  @override
  _JobEstimatesListScreenState createState() => _JobEstimatesListScreenState();
}

class _JobEstimatesListScreenState
    extends AsyncState<JobEstimatesListScreen, void> {
  late Future<List<Job>> _jobs;
  bool showOnlyActiveJobs = true;

  @override
  Future<void> asyncInitState() async {
    await _refreshJobs();
  }

  Future<void> _refreshJobs() async {
    setState(() {
      _jobs = _fetchJobs();
    });
  }

  Future<List<Job>> _fetchJobs() async {
    // If showOnlyActiveJobs is true, show only active jobs, else show all jobs
    if (showOnlyActiveJobs) {
      return DaoJob().getActiveJobs(null);
    } else {
      // getByFilter(null) returns all jobs sorted by modified_date desc
      return DaoJob().getByFilter(null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Job Estimates'),
          actions: [
            Row(
              children: [
                const Text('Show All Jobs'),
                Switch(
                  value: !showOnlyActiveJobs,
                  onChanged: (value) async {
                    showOnlyActiveJobs = !value;
                    await _refreshJobs();
                    setState(() {});
                  },
                ),
              ],
            ),
          ],
        ),
        body: FutureBuilderEx<List<Job>>(
          future: _jobs,
          builder: (context, jobs) {
            if (jobs == null || jobs.isEmpty) {
              return const Center(child: Text('No jobs found.'));
            }

            return ListView.builder(
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return JobCard(
                  job: job,
                  onEstimatesUpdated: _refreshJobs, // Refresh on return
                );
              },
            );
          },
        ),
      );
}

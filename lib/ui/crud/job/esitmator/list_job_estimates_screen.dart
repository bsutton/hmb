/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../../dao/dao.g.dart';
import '../../../../entity/entity.g.dart';
import '../../../../util/app_title.dart';
import '../../../widgets/hmb_search.dart';
import '../../../widgets/hmb_toggle.dart';
import '../../../widgets/layout/hmb_spacer.dart';
import 'job_card.dart'; // The JobCard from previous snippet

class JobEstimatesListScreen extends StatefulWidget {
  const JobEstimatesListScreen({super.key});

  @override
  _JobEstimatesListScreenState createState() => _JobEstimatesListScreenState();
}

class _JobEstimatesListScreenState
    extends DeferredState<JobEstimatesListScreen> {
  late Future<List<CustomerAndJob>> _jobs;
  var _showOnlyActiveJobs = true;

  var _searchQuery = '';

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Estimates');
    await _refreshJobs();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onSearchChanged(String? filter) {
    setState(() {
      _searchQuery = filter?.trim().toLowerCase() ?? '';
    });
  }

  Future<void> _refreshJobs() async {
    _jobs = _fetchJobs();
    setState(() {});
  }

  Future<List<CustomerAndJob>> _fetchJobs() async {
    List<Job> rawJobs;
    if (_showOnlyActiveJobs) {
      rawJobs = await DaoJob().getQuotableJobs(null);
    } else {
      rawJobs = await DaoJob().getByFilter(null);
    }

    final jobList = <CustomerAndJob>[];
    for (final job in rawJobs) {
      final customer = await DaoCustomer().getByJob(job.id);
      if (customer == null) {
        continue;
      }

      final contact = await DaoContact().getPrimaryForJob(job.id);
      final hasBillables = await _hasBillableItems(job);
      jobList.add(
        CustomerAndJob(
          customer: customer,
          job: job,
          hasBillables: hasBillables,
          contactName: contact?.fullname,
        ),
      );
    }

    return jobList;
  }

  Future<bool> _hasBillableItems(Job job) async {
    final hasBillableTasks = await DaoJob().hasBillableTasks(job);
    final hasBillableBookingFee = await DaoJob().hasBillableBookingFee(job);
    return hasBillableTasks || hasBillableBookingFee;
  }

  List<CustomerAndJob> _filterJobs(List<CustomerAndJob> jobs) {
    if (_searchQuery.isEmpty) {
      return jobs;
    }
    return jobs.where((cj) {
      final customerName = cj.customer.name.toLowerCase();
      final jobSummary = cj.job.summary.toLowerCase();
      final contactName = (cj.contactName ?? '').toLowerCase();

      return customerName.contains(_searchQuery) ||
          jobSummary.contains(_searchQuery) ||
          contactName.contains(_searchQuery);
    }).toList();
  }

  final double _searchBarRowHeight = 80; // Adjust as needed for your search bar
  final double _switchRowHeight = 50; //

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: _searchBarRowHeight + _switchRowHeight,
      title: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: HMBSearch(
                  onChanged: (filter) async => _onSearchChanged(filter),
                ),
              ),
            ],
          ),
          Row(
            // New Row for the Switch
            mainAxisAlignment: MainAxisAlignment.end, // Align to the right
            children: [
              HMBToggle(
                label: 'Show All Jobs',
                initialValue: !_showOnlyActiveJobs,
                onToggled: (value) async {
                  setState(() {
                    _showOnlyActiveJobs = !value;
                  });
                  await _refreshJobs();
                },
                tooltip: '',
              ),
            ],
          ),
        ],
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: FutureBuilderEx<List<CustomerAndJob>>(
            future: _jobs,
            builder: (context, jobs) {
              if (jobs == null || jobs.isEmpty) {
                return const Center(
                  child: Text(
                    'No jobs found. Only Jobs with a status of Quoting or Prospecting are shown',
                  ),
                );
              }

              final filteredJobs = _filterJobs(jobs);
              if (filteredJobs.isEmpty) {
                return const Center(child: Text('No matches for your search.'));
              }

              return ListView.builder(
                itemCount: filteredJobs.length,
                itemBuilder: (context, index) {
                  final cj = filteredJobs[index];
                  return Column(
                    children: [
                      const HMBSpacer(height: true),
                      JobCard(job: cj.job, onEstimatesUpdated: _refreshJobs),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class CustomerAndJob {
  CustomerAndJob({
    required this.customer,
    required this.job,
    required this.hasBillables,
    this.contactName,
  });

  final Customer customer;
  final Job job;
  final bool hasBillables;
  final String? contactName;
}

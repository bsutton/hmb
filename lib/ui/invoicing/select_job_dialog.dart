/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../widgets/surface.dart';

class SelectJobDialog extends StatefulWidget {
  const SelectJobDialog({super.key});

  @override
  _SelectJobDialogState createState() => _SelectJobDialogState();

  static Future<Job?> show(BuildContext context) => showDialog<Job>(
    context: context,
    builder: (context) => const SelectJobDialog(),
  );
}

class _SelectJobDialogState extends State<SelectJobDialog> {
  var _showAllJobs = false;
  var _showJobsWithNoBillableItems = false;

  final _searchController = TextEditingController();
  var _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<List<CustomerAndJob>> _fetchJobs() => CustomerAndJob.getJobs(
    showAllJobs: _showAllJobs,
    showJobsWithNoBillableItems: _showJobsWithNoBillableItems,
  );

  List<CustomerAndJob> _filterJobs(List<CustomerAndJob> jobs) {
    if (_searchQuery.isEmpty) {
      return jobs;
    }

    return jobs.where((cj) {
      final customerName = cj.customer.name.toLowerCase();
      final jobSummary = cj.job.summary.toLowerCase();
      return customerName.contains(_searchQuery) ||
          jobSummary.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: EdgeInsets.zero,
    backgroundColor: Theme.of(context).canvasColor,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Select Job'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                CheckboxListTile(
                  title: const Text('Show all jobs'),
                  value: _showAllJobs,
                  onChanged: (value) {
                    setState(() {
                      _showAllJobs = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: const Text('Show jobs with no billable items'),
                  value: _showJobsWithNoBillableItems,
                  onChanged: (value) {
                    setState(() {
                      _showJobsWithNoBillableItems = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilderEx<List<CustomerAndJob>>(
              // ignore: discarded_futures
              future: _fetchJobs(),
              builder: (context, jobs) {
                if (jobs == null || jobs.isEmpty) {
                  return const Center(child: Text('No jobs found.'));
                }

                final filteredJobs = _filterJobs(jobs);

                if (filteredJobs.isEmpty) {
                  return const Center(
                    child: Text('No matches for your search.'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredJobs.length,
                  itemBuilder: (context, index) {
                    final current = filteredJobs[index];
                    return SurfaceCard(
                      title: current.job.summary,
                      body: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer: ${current.customer.name}'),
                          Text(
                            'Has billable items: ${current.hasBillables ? "Yes" : "No"}',
                          ),
                        ],
                      ),
                      onPressed: () => _onPressed(current),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  void _onPressed(CustomerAndJob current) {
    if (mounted) {
      Navigator.pop(context, current.job);
    }
  }
}

class CustomerAndJob {
  CustomerAndJob(this.customer, this.job, {required this.hasBillables});

  final Customer customer;
  final Job job;
  final bool hasBillables;

  static Future<List<CustomerAndJob>> getJobs({
    required bool showAllJobs,
    required bool showJobsWithNoBillableItems,
  }) async {
    final jobs = showAllJobs
        ? await DaoJob().getAll()
        : await DaoJob().getActiveJobs(null);

    final jobList = <CustomerAndJob>[];

    for (final job in jobs) {
      final customer = await DaoCustomer().getByJob(job.id);
      if (customer == null) {
        continue;
      }

      final hasBillables = await hasBillableItems(job);
      if (!showJobsWithNoBillableItems && !hasBillables) {
        continue;
      }

      jobList.add(CustomerAndJob(customer, job, hasBillables: hasBillables));
    }

    return jobList;
  }

  static Future<bool> hasBillableItems(Job job) async {
    final hasBillableTasks = await DaoJob().hasBillableTasks(job);
    final hasBillableBookingFee = await DaoJob().hasBillableBookingFee(job);
    return hasBillableTasks || hasBillableBookingFee;
  }
}

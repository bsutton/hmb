import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';

class SelectJobDialog extends StatefulWidget {
  const SelectJobDialog({super.key});

  @override
  _SelectJobDialogState createState() => _SelectJobDialogState();
}

class _SelectJobDialogState extends State<SelectJobDialog> {
  bool showAllJobs = false;
  bool showJobsWithNoBillableItems = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    _searchController..removeListener(_onSearchChanged)
    ..dispose();
    super.dispose();
  }

  Future<List<CustomerAndJob>> _fetchJobs() => CustomerAndJob.getJobs(
        showAllJobs: showAllJobs,
        showJobsWithNoBillableItems: showJobsWithNoBillableItems,
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
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Select Job'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('Show all jobs'),
              value: showAllJobs,
              onChanged: (value) {
                setState(() {
                  showAllJobs = value ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Show jobs with no billable items'),
              value: showJobsWithNoBillableItems,
              onChanged: (value) {
                setState(() {
                  showJobsWithNoBillableItems = value ?? false;
                });
              },
            ),
            FutureBuilderEx<List<CustomerAndJob>>(
              // ignore: discarded_futures
              future: _fetchJobs(),
              builder: (context, jobs) {
                if (jobs == null || jobs.isEmpty) {
                  return const Center(child: Text('No jobs found.'));
                }

                final filteredJobs = _filterJobs(jobs);

                if (filteredJobs.isEmpty) {
                  return const Center(
                      child: Text('No matches for your search.'));
                }

                return SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: ListView.builder(
                    itemCount: filteredJobs.length,
                    itemBuilder: (context, index) {
                      final current = filteredJobs[index];
                      return ListTile(
                        title: Text(current.job.summary),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Customer: ${current.customer.name}'),
                            Text(
                                'Has billable items: ${current.hasBillables ? "Yes" : "No"}')
                          ],
                        ),
                        onTap: () => Navigator.pop(context, current.job),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by Customer or Job Summary',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      );
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
    List<Job> jobs;

    if (showAllJobs) {
      jobs = await DaoJob().getAll();
    } else {
      jobs = await DaoJob().getActiveJobs(null);
    }

    final jobList = <CustomerAndJob>[];

    for (final job in jobs) {
      final customer = await DaoCustomer().getByJob(job.id);
      if (customer == null) {
        continue;
      }

      final hasBillables = await hasBillableItems(job);

      if (!showJobsWithNoBillableItems && !hasBillables) {
        // Skip jobs without billables if not requested
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

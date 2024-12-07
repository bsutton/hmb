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
              future: CustomerAndJob.getJobs(
                showAllJobs: showAllJobs,
                showJobsWithNoBillableItems: showJobsWithNoBillableItems,
              ),
              builder: (context, jobs) {
                if (jobs == null || jobs.isEmpty) {
                  return const Center(child: Text('No jobs found.'));
                }

                return SizedBox(
                  width: double.maxFinite,
                  height: 300, // Set a fixed height for the list
                  child: ListView.builder(
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final current = jobs[index];
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
      jobs = await DaoJob().getActiveJobs(null); // Fetch active jobs
    }

    final jobList = <CustomerAndJob>[];

    for (final job in jobs) {
      final customer = await DaoCustomer().getByJob(job.id);
      final hasBillables = await hasBillableItems(job);

      if (!showJobsWithNoBillableItems && !hasBillables) {
        // Skip jobs without billables if the checkbox is not selected
        continue;
      }

      jobList.add(CustomerAndJob(customer!, job, hasBillables: hasBillables));
    }

    return jobList;
  }

  static Future<bool> hasBillableItems(Job job) async {
    final hasBillableTasks = await DaoJob().hasBillableTasks(job);
    final hasBillableBookingFee = await DaoJob().hasBillableBookingFee(job);

    return hasBillableTasks || hasBillableBookingFee;
  }
}

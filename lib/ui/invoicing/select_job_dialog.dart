import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';

class SelectJobDialog extends StatelessWidget {
  const SelectJobDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Select Active Job'),
        content: FutureBuilderEx<List<CustomerAndJob>>(
          // ignore: discarded_futures
          future: CustomerAndJob.getActiveJobs(),
          builder: (context, active) {
            if (active!.isEmpty) {
              return const Center(child: Text('No active jobs found.'));
            }

            return SizedBox(
              width: double.maxFinite,
              height: 300, // Adjust height as needed
              child: ListView.builder(
                itemCount: active.length,
                itemBuilder: (context, index) {
                  final current = active[index];
                  return ListTile(
                    title: Text(current.job.summary),
                    subtitle: Text('Customer: ${current.customer.name}'),
                    onTap: () => Navigator.pop(context, current.job),
                  );
                },
              ),
            );
          },
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
  CustomerAndJob(this.customer, this.job);
  Customer customer;
  Job job;

  static Future<List<CustomerAndJob>> getActiveJobs() async {
    final jobs = await DaoJob().getActiveJobs(null);

    final active = <CustomerAndJob>[];

    for (final job in jobs) {
      final customer = await DaoCustomer().getByJob(job.id);
      active.add(CustomerAndJob(customer!, job));
    }

    return active;
  }
}

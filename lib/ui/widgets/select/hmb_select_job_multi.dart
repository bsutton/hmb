import 'package:flutter/widgets.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../widgets.g.dart';
import 'hmb_droplist_multi.dart';

class HMBSelectJobMulti extends StatelessWidget {
  final List<Job> initialJobs;
  final void Function(List<Job>) onChanged;

  const HMBSelectJobMulti({
    required this.initialJobs,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) =>
      HMBDroplistMultiSelect<CustomerAndJob>(
        initialItems: () => CustomerAndJob.fromList(initialJobs),
        // ignore: discarded_futures
        items: CustomerAndJob.getByFilter,
        format: (candj) => '${candj.customer.name}\n${candj.job.summary}',
        onChanged: (selectedJobs) {
          onChanged(selectedJobs.map((candj) => candj.job).toList());
        },
        title: 'Jobs',
        backgroundColor: SurfaceElevation.e4.color,
        required: false,
      ).help(
        'Filter by Job',
        '''
Allows you to filter the list to items from specific Jobs.

If your Job isn't showing then you need to update its status to an Active one such as 'Scheduled, In Progress...' ''',
      );
}

@immutable
class CustomerAndJob {
  final Customer customer;
  final Job job;

  const CustomerAndJob._internal(this.customer, this.job);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CustomerAndJob &&
        other.customer.id == customer.id &&
        other.job.id == job.id;
  }

  @override
  int get hashCode => Object.hash(customer.id, job.id);

  static Future<List<CustomerAndJob>> fromList(List<Job> jobs) async {
    final list = <CustomerAndJob>[];

    final daoCustomer = DaoCustomer();
    for (final job in jobs) {
      final customer = await daoCustomer.getByJob(job.id);
      list.add(CustomerAndJob._internal(customer!, job));
    }
    return list;
  }

  static Future<List<CustomerAndJob>> getByFilter(String? filter) async {
    final jobs = await DaoJob().getActiveJobs(filter);

    final list = <CustomerAndJob>[];

    final daoCustomer = DaoCustomer();
    for (final job in jobs) {
      final customer = await daoCustomer.getByJob(job.id);
      list.add(CustomerAndJob._internal(customer!, job));
    }
    return list;
  }
}

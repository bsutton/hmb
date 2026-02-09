/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../../../dao/dao_job.dart';
import '../../../entity/customer.dart';
import '../../../entity/job.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../source_context.dart';
import 'source.dart';

class JobSource extends Source<Job> {
  final customerNotifier = ValueNotifier<CustomerJob>(CustomerJob(null, null));

  Job? job;

  JobSource() : super(name: 'job');

  @override
  Widget widget() => ValueListenableBuilder(
    valueListenable: customerNotifier,
    builder: (context, customerJob, _) => HMBDroplist<Job>(
      title: 'Job',
      selectedItem: () async => customerJob.job,
      items: (filter) => DaoJob().getByCustomer(customerJob.customer),
      format: (job) => customerJob.job?.summary ?? '',
      onChanged: (job) {
        this.job = job;
        onChanged(job, ResetFields(contact: true, site: true));
      },
    ),
  );

  @override
  Job? get value => job;

  @override
  void dependencyChanged(Source<dynamic> source, SourceContext sourceContext) {
    if (source == this) {
      return;
    }
    customerNotifier.value = CustomerJob(
      sourceContext.customer,
      sourceContext.job,
    );
  }

  @override
  void revise(SourceContext sourceContext) {
    sourceContext.job = job;
  }
}

class CustomerJob {
  Customer? customer;
  Job? job;

  CustomerJob(this.customer, this.job);
}

import 'package:flutter/material.dart';

import '../../../dao/dao_job.dart';
import '../../../entity/job.dart';
import '../../select/hmb_droplist.dart';
import '../message_template_dialog.dart';
import 'customer_source.dart';
import 'source.dart';

class JobSource extends Source<Job> {
  JobSource({required this.customerSource}) : super(name: 'job') {
    customerSource.onChanged = (customer) {
      // Reset job value when customer changes
      setValue(null);
    };
  }
  final CustomerSource customerSource;

  @override
  Widget field(MessageData data) => HMBDroplist<Job>(
        title: 'Job',
        selectedItem: () async => value,
        items: (filter) async {
          if (customerSource.value != null) {
            return DaoJob().getByCustomer(customerSource.value!, filter);
          } else {
            return [];
          }
        },
        format: (job) => job.summary,
        onChanged: setValue,
      );
}
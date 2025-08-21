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

import '../../../dao/dao_job_activity.dart';
import '../../../entity/job.dart';
import '../../../entity/job_activity.dart';
import '../../../util/format.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../source_context.dart';
import 'source.dart';

class JobActivitySource extends Source<JobActivity> {
  JobActivitySource() : super(name: 'job_activity');
  final notifier = ValueNotifier<JobAndActivity>(JobAndActivity(null, null));

  JobActivity? jobActivity;

  @override
  Widget widget() => ValueListenableBuilder(
    valueListenable: notifier,
    builder: (context, jobAndActivity, _) => HMBDroplist<JobActivity>(
      title: 'Activity',
      selectedItem: () async => jobAndActivity.jobActivity,
      // ignore: discarded_futures
      items: (filter) => DaoJobActivity().getByJob(jobAndActivity.job?.id),
      format: (jobActivity) => jobAndActivity.jobActivity != null
          ? formatDate(jobAndActivity.jobActivity!.start)
          : '',
      onChanged: (jobActivity) {
        this.jobActivity = jobActivity;
        onChanged(jobActivity, ResetFields(contact: true, site: true));
      },
    ),
  );

  @override
  JobActivity? get value => jobActivity;

  @override
  void dependencyChanged(Source<dynamic> source, SourceContext sourceContext) {
    if (source == this) {
      return;
    }
    notifier.value = JobAndActivity(
      sourceContext.jobActivity,
      sourceContext.job,
    );
  }

  @override
  void revise(SourceContext sourceContext) {
    sourceContext.jobActivity = jobActivity;
  }
}

class JobAndActivity {
  JobAndActivity(this.jobActivity, this.job);

  Job? job;
  JobActivity? jobActivity;
}

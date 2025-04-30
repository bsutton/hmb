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
    builder:
        (context, jobAndActivity, _) => HMBDroplist<JobActivity>(
          title: 'Activity',
          selectedItem: () async => jobAndActivity.jobActivity,
          items: (filter) => DaoJobActivity().getByJob(jobAndActivity.job?.id),
          format:
              (jobActivity) =>
                  jobAndActivity.jobActivity != null
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

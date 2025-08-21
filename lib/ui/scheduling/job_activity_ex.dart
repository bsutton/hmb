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

import 'package:calendar_view/calendar_view.dart';

import '../../dao/dao_job.dart';
import '../../entity/job.dart';
import '../../entity/job_activity.dart';

/// Our extended class that includes the Job, etc.
class JobActivityEx {
  JobActivityEx._({required this.jobActivity, required this.job});

  static Future<JobActivityEx> fromActivity(JobActivity jobActivity) async {
    final job = await DaoJob().getById(jobActivity.jobId);

    return JobActivityEx._(job: job!, jobActivity: jobActivity);
  }

  final JobActivity jobActivity;
  final Job job;

  /// Convert to [CalendarEventData] for the calendar_view package
  CalendarEventData<JobActivityEx> get eventData => CalendarEventData(
    title: job.summary,
    description: jobActivity.notes,
    date: jobActivity.start.withoutTime,
    startTime: jobActivity.start,
    endTime: jobActivity.end,
    color: jobActivity.status.color,
    event: this,
  );

  int get durationInMinutes =>
      jobActivity.end.difference(jobActivity.start).inMinutes;
}

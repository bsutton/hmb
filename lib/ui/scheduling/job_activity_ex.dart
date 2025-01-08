import 'package:calendar_view/calendar_view.dart';

import '../../dao/dao_job.dart';
import '../../entity/job.dart';
import '../../entity/job_activity.dart';
import '../widgets/media/rich_editor.dart';

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
        description: RichEditor.createParchment(job.description)
            .toPlainText()
            .replaceAll('\n\n', '\n'),
        date: jobActivity.start.withoutTime,
        startTime: jobActivity.start,
        endTime: jobActivity.end,
        color: jobActivity.status.color,
        event: this,
      );

  int get durationInMinutes =>
      jobActivity.end.difference(jobActivity.start).inMinutes;
}

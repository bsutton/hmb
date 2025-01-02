import 'package:calendar_view/calendar_view.dart';

import '../../dao/dao_job.dart';
import '../../entity/job.dart';
import '../../entity/job_event.dart';
import '../widgets/media/rich_editor.dart';

/// Our extended class that includes the Job, etc.
class JobEventEx {
  JobEventEx._({required this.jobEvent, required this.job});

  static Future<JobEventEx> fromEvent(JobEvent jobEvent) async {
    final job = await DaoJob().getById(jobEvent.jobId);

    return JobEventEx._(job: job!, jobEvent: jobEvent);
  }

  final JobEvent jobEvent;
  final Job job;

  /// Convert to [CalendarEventData] for the calendar_view package
  CalendarEventData<JobEventEx> get eventData => CalendarEventData(
        title: job.summary,
        description: RichEditor.createParchment(job.description)
            .toPlainText()
            .replaceAll('\n\n', '\n'),
        date: jobEvent.startDate.withoutTime,
        startTime: jobEvent.startDate,
        endTime: jobEvent.endDate,
        event: this,
      );
}

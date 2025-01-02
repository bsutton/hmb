// schedule_page.dart

import 'package:calendar_view/calendar_view.dart';
import '../../dao/dao_job.dart';
import '../../entity/job.dart';
import '../../entity/job_event.dart';
import '../widgets/media/rich_editor.dart';

class JobEventEx {
  JobEventEx._(this.job, this.jobEvent);

  static Future<JobEventEx> fromEvent(JobEvent jobEvent) async {
    final job = await DaoJob().getById(jobEvent.jobId);

    return JobEventEx._(job!, jobEvent);
  }

  final JobEvent jobEvent;
  late final Job job;

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

import '../../../entity/job_activity.dart';
import '../../../util/date_time_ex.dart';
import '../../../util/format.dart';
import '../../../util/local_date.dart';
import 'date_source.dart';
import 'place_holder.dart';

class JobActivityDate extends PlaceHolder<JobActivity> {
  JobActivityDate({required super.source})
      : super(name: tagName, base: tagBase);

  static String tagName = 'job_activity.start_date';
  static String tagBase = 'job_activity';
  static String label = 'Activity Date';

  @override
  Future<String> value() async =>
      formatLocalDate(source.value?.start.toLocalDate() ?? LocalDate.today());
}

class JobActivityTime extends PlaceHolder<JobActivity> {
  JobActivityTime({required super.source})
      : super(
          name: tagName,
          base: tagBase,
        );

  static String tagName = 'job_activity.start_time';
  static String tagBase = 'job_activity';
  static String label = 'Activity Time';

  @override
  Future<String> value() async => source.value != null
      ? formatLocalTime(source.value!.start.toLocalTime())
      : '';
}

class OriginalDate extends PlaceHolder<LocalDate> {
  OriginalDate({required this.dateSource})
      : super(name: tagName, base: tagBase, source: dateSource);

  static String tagName = 'job_activity.original_date';
  static String tagBase = 'job_activity.original_date';
  static String label = 'Original Date';

  DateSource dateSource;

  @override
  Future<String> value() async => formatLocalDate(dateSource.date!);
}

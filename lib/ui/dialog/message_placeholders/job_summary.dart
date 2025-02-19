import '../../../entity/job.dart';
import 'job_source.dart';
import 'place_holder.dart';

class JobSummary extends PlaceHolder<Job> {
  JobSummary({required this.jobSource})
    : super(name: tagName, base: tagBase, source: jobSource);

  static String get tagName => 'job.summary';
  static String tagBase = 'job';

  final JobSource jobSource;

  @override
  Future<String> value() async {
    final job = jobSource.value;
    if (job != null) {
      return job.summary;
    } else {
      return '';
    }
  }
}

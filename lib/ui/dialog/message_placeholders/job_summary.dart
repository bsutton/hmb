import '../../../entity/job.dart';
import '../message_template_dialog.dart';
import 'job_source.dart';
import 'place_holder.dart';

class JobSummary extends PlaceHolder<String, Job> {
  JobSummary({required this.jobSource})
      : super(name: tagName, base: tagBase, source: jobSource);

  static String get tagName => 'job.summary';
  static String tagBase = 'job';

  final JobSource jobSource;

  @override
  Future<String> value(MessageData data) async {
    final job = jobSource.value;
    if (job != null) {
      return job.summary;
    } else {
      return '';
    }
  }

  @override
  void setValue(String? value) {
    // Not used; value comes from jobSource
  }
}

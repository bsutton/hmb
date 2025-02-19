import '../../../entity/job.dart';
import 'job_source.dart';
import 'place_holder.dart';

class JobDescription extends PlaceHolder<Job> {
  JobDescription({required this.jobSource})
    : super(name: tagName, base: tagBase, source: jobSource);

  static const String tagName = 'job.description';

  static const String tagBase = 'job';
  final JobSource jobSource;

  @override
  Future<String> value() async {
    final job = jobSource.value;
    return job?.description ?? '';
  }
}

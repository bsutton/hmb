import '../../../dao/dao_job.dart';
import '../../../entity/job.dart';
import 'job_source.dart';
import 'place_holder.dart';

class JobCost extends PlaceHolder<Job> {
  JobCost({required this.jobSource})
    : super(name: tagName, base: tagBase, source: jobSource);

  static String get tagName => 'job.cost';
  static String tagBase = 'job';

  final JobSource jobSource;

  @override
  Future<String> value() async {
    final job = jobSource.value;
    if (job != null) {
      return (await DaoJob().getJobStatistics(job)).totalCost.toString();
    } else {
      return '';
    }
  }
}

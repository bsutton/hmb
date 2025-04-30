import '../../../dao/dao_job.dart';
import '../../../entity/job.dart';
import 'job_source.dart';
import 'place_holder.dart';

class JobCost extends PlaceHolder<Job> {
  JobCost({required this.jobSource})
    : super(name: tagName, base: _tagBase, source: jobSource);

  // ignore: omit_obvious_property_types
  static String tagName = 'job.cost';
  static const _tagBase = 'job';

  final JobSource jobSource;

  @override
  Future<String> value() async {
    final job = jobSource.value;
    if (job != null) {
      return (await DaoJob().getJobStatistics(
        job,
      )).totalMaterialCost.toString();
    } else {
      return '';
    }
  }
}

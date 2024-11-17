import '../../../dao/dao_job.dart';
import '../../../entity/job.dart';
import '../../select/hmb_droplist.dart';
import '../message_template_dialog.dart';
import 'place_holder.dart';

abstract class JobHolder implements PlaceHolder<Job> {
  Job? get job;
  set job(Job? job);
  @override
  void setValue(Job? value);
}

///
/// JobName
///
class JobName extends PlaceHolder<Job> implements JobHolder {
  JobName() : super(name: keyName, key: keyScope);

  static String keyName = 'job';
  static String keyScope = 'job';
  @override
  Job? job;
  @override
  Future<String> value(MessageData data) async => data.job!.summary;

  @override
  PlaceHolderField<Job> field(MessageData data) =>
      _buildJobDroplist(this, data);

  @override
  void setValue(Job? value) => job = value;


  void Function(Job? value, ResetFields)? listen;
}

///
/// JobCost
///
class JobCost extends PlaceHolder<Job> implements JobHolder {
  JobCost() : super(name: keyName, key: keyScope);

  static String keyName = 'job_cost';
  static String keyScope = 'job';

  @override
  Job? job;
  @override
  Future<String> value(MessageData data) async =>
      (await DaoJob().getJobStatistics(job!)).totalCost.toString();

  @override
  PlaceHolderField<Job> field(MessageData data) =>
      _buildJobDroplist(this, data);

  @override
  void setValue(Job? value) => job = value;

}

class JobDescription extends PlaceHolder<Job> implements JobHolder {
  JobDescription() : super(name: keyName, key: keyScope);

  static String keyName = 'job_description';
  static String keyScope = 'job';

  @override
  Job? job;
  @override
  Future<String> value(MessageData data) async => data.job!.description;

  @override
  PlaceHolderField<Job> field(MessageData data) =>
      _buildJobDroplist(this, data);

  @override
  void setValue(Job? value) => job = value;

}

/// Job placeholder drop list
PlaceHolderField<Job> _buildJobDroplist(
    JobHolder placeholder, MessageData data) {
  placeholder.setValue(data.job);

  final widget = HMBDroplist<Job>(
    title: 'Job',
    selectedItem: () async => placeholder.job,
    items: (filter) async => DaoJob().getByFilter(filter),
    format: (job) => placeholder.job?.summary ?? '',
    onChanged: (job) {
      placeholder.job = job;
      // Reset site and contact when Job changes
      placeholder.onChanged?.call(job, ResetFields(site: true, contact: true));
    },
  );
  return PlaceHolderField(
      placeholder: placeholder,
      widget: widget,
      getValue: (data) async => placeholder.value(data));
}

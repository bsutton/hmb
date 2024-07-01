// ignore_for_file: library_private_types_in_public_api

import '../../entity/contact.dart';
import '../../entity/job.dart';
import '../dao_contact.dart';
import '../dao_contact_job.dart';
import 'dao_join_adaptor.dart';

class JoinAdaptorJobContact implements DaoJoinAdaptor<Contact, Job> {
  @override
  Future<void> deleteFromParent(Contact contact, Job job) async {
    await DaoContactJob().deleteJoin(job, contact);
  }

  @override
  Future<List<Contact>> getByParent(Job? job) async =>
      DaoContact().getByJob(job?.id);

  @override
  Future<void> insertForParent(Contact contact, Job job) async {
    await DaoContact().insertForJob(contact, job);
  }

  @override
  Future<void> setAsPrimary(Contact child, Job job) async {
    await DaoContactJob().setAsPrimary(child, job);
  }
}

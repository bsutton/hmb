// ignore_for_file: library_private_types_in_public_api

import '../../entity/job.dart';
import '../../entity/site.dart';
import '../dao_site.dart';
import '../dao_site_job.dart';
import 'dao_join_adaptor.dart';

class JoinAdaptorJobSite implements DaoJoinAdaptor<Site, Job> {
  @override
  Future<void> deleteFromParent(Site site, Job job) async {
    await DaoSiteJob().deleteJoin(job, site);
  }

  @override
  Future<List<Site>> getByParent(Job? job) async {
    final site = await DaoSite().getByJob(job);

    if (site == null) {
      return [];
    }

    return [site];
  }

  @override
  Future<void> insertForParent(Site site, Job job) async {
    await DaoSite().insertForJob(site, job);
  }

  @override
  Future<void> setAsPrimary(Site child, Job job) async {
    await DaoSiteJob().setAsPrimary(child, job);
  }
}

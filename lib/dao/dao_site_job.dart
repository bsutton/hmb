import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/job.dart';
import '../entity/site.dart';
import 'dao.dart';

class DaoSiteJob extends Dao<Site> {
  Future<void> createTable(Database db, int version) async {}

  @override
  Site fromMap(Map<String, dynamic> map) => Site.fromMap(map);

  @override
  String get tableName => 'job_site';

  Future<void> deleteJoin(Job job, Site site,
      [Transaction? transaction]) async {
    await getDb(transaction).delete(
      tableName,
      where: 'job_id = ? and site_id = ?',
      whereArgs: [job.id, site.id],
    );
  }

  Future<void> insertJoin(Site site, Job job,
      [Transaction? transaction]) async {
    await getDb(transaction).insert(
      tableName,
      {'job_id': job.id, 'site_id': site.id},
    );
  }

  Future<void> setAsPrimary(Site site, Job job,
      [Transaction? transaction]) async {
    await getDb(transaction).update(
      tableName,
      {'primary': 1},
      where: 'job_id = ? and site_id = ?',
      whereArgs: [job.id, site.id],
    );
  }

  @override
  JuneStateCreator get juneRefresher => SiteJobState.new;
}

/// Used to notify the UI that the time entry has changed.
class SiteJobState extends JuneState {
  SiteJobState();
}

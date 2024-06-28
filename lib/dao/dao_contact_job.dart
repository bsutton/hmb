import 'package:june/state_manager/src/simple/controllers.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/contact.dart';
import '../entity/job.dart';
import 'dao.dart';

// TODO(bsutton): is this table need as the job has a contactId.
/// and I think it can only have a  single contact.
class DaoContactJob extends Dao<Contact> {
  Future<void> createTable(Database db, int version) async {}

  @override
  Contact fromMap(Map<String, dynamic> map) => Contact.fromMap(map);

  @override
  String get tableName => 'job_contact';

  Future<void> deleteJoin(Job job, Contact contact,
      [Transaction? transaction]) async {
    await getDb(transaction).delete(
      tableName,
      where: 'job_id = ? and contact_id = ?',
      whereArgs: [job.id, contact.id],
    );
  }

  Future<void> insertJoin(Contact contact, Job job,
      [Transaction? transaction]) async {
    await getDb(transaction).insert(
      tableName,
      {'job_id': job.id, 'contact_id': contact.id},
    );
  }

  Future<void> setAsPrimary(Contact contact, Job job,
      [Transaction? transaction]) async {
    await getDb(transaction).update(
      tableName,
      {'primary': 1},
      where: 'job_id = ? and contact_id = ?',
      whereArgs: [job.id, contact.id],
    );
  }

  @override
  JuneStateCreator get juneRefresher => ContactJobState.new;
}

/// Used to notify the UI that the time entry has changed.
class ContactJobState extends JuneState {
  ContactJobState();
}

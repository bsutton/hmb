import 'package:sqflite_common/sqlite_api.dart';

import '../entity/contact.dart';
import '../entity/contact_role.dart';
import '../entity/job.dart';
import '../util/dart/exceptions.dart';
import 'dao.dart';
import 'dao_contact.dart';
import 'dao_job.dart';
import 'dao_job_party.dart';

class DaoContactRole {
  Database get _db => DatabaseHelper.instance.database;

  Future<List<ContactRole>> getAll([Transaction? transaction]) async =>
      (await (transaction ?? _db).query(
        'contact_role',
        orderBy: 'builtin DESC, name COLLATE NOCASE',
      )).map(ContactRole.fromMap).toList();

  Future<ContactRole?> getById(int? id, [Transaction? transaction]) async {
    if (id == null) {
      return null;
    }
    final rows = await (transaction ?? _db).query(
      'contact_role',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : ContactRole.fromMap(rows.first);
  }

  Future<int> create(String name, [Transaction? transaction]) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw HMBException('Enter a role name.');
    }
    return (transaction ?? _db).insert('contact_role', {'name': trimmed});
  }

  Future<void> rename(int id, String name) async {
    await _db.transaction((txn) async {
      final role = await getById(id, txn);
      if (role == null || role.builtin) {
        throw HMBException('Standard roles cannot be renamed.');
      }
      if (name.trim().isEmpty) {
        throw HMBException('Enter a role name.');
      }
      await txn.update(
        'contact_role',
        {'name': name.trim()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'contact',
        {'role_description': name.trim()},
        where: 'default_role_id = ?',
        whereArgs: [id],
      );
    });
    Dao.notifier(DaoContact());
  }

  Future<ContactRoleUsage> getUsage(int roleId) async {
    final contacts = DaoContact().toList(
      await _db.query(
        'contact',
        where: 'default_role_id = ?',
        whereArgs: [roleId],
        orderBy: 'firstName, surname',
      ),
    );
    final assignments = <({Job job, Contact contact})>[];
    final rows = await _db.query(
      'job_party',
      where: 'role_id = ?',
      whereArgs: [roleId],
      orderBy: 'job_id, id',
    );
    for (final row in rows) {
      final job = await DaoJob().getById(row['job_id']! as int);
      final contact = await DaoContact().getById(row['contact_id']! as int);
      if (job != null && contact != null) {
        assignments.add((job: job, contact: contact));
      }
    }
    return ContactRoleUsage(contacts: contacts, assignments: assignments);
  }

  /// Move every usage together; conflicts leave all records unchanged.
  Future<void> reassign(int sourceId, int targetId) async {
    if (sourceId == targetId) {
      throw HMBException('Choose a different replacement role.');
    }
    final changedJobs = <int>{};
    await _db.transaction((txn) async {
      final source = await getById(sourceId, txn);
      final target = await getById(targetId, txn);
      if (source == null || target == null) {
        throw HMBException('Select existing roles.');
      }
      final rows = await txn.query(
        'job_party',
        where: 'role_id = ?',
        whereArgs: [sourceId],
        orderBy: 'job_id, id',
      );
      for (final row in rows) {
        final jobId = row['job_id']! as int;
        final contactId = row['contact_id']! as int;
        final assignmentId = row['id']! as int;
        final duplicate = await txn.query(
          'job_party',
          where: 'job_id = ? AND contact_id = ? AND role_id = ?',
          whereArgs: [jobId, contactId, targetId],
        );
        try {
          await DaoJobParty().save(
            jobId: jobId,
            contactId: contactId,
            roleId: targetId,
            assignmentId: duplicate.isEmpty
                ? assignmentId
                : duplicate.single['id']! as int,
            transaction: txn,
          );
          if (duplicate.isNotEmpty) {
            await DaoJobParty().delete(jobId, assignmentId, transaction: txn);
          }
        } catch (error) {
          throw HMBException(
            'Job #$jobId: $error '
            'No roles were reassigned. Resolve this job’s parties first.',
          );
        }
        changedJobs.add(jobId);
      }
      final contacts = DaoContact().toList(
        await txn.query(
          'contact',
          where: 'default_role_id = ?',
          whereArgs: [sourceId],
        ),
      );
      for (final contact in contacts) {
        contact.defaultRoleId = targetId;
        await DaoContact().update(contact, txn);
      }
    });
    Dao.notifier(DaoContact());
    for (final jobId in changedJobs) {
      Dao.notifier(DaoJob(), jobId);
    }
  }

  Future<void> delete(int id) async {
    await _db.transaction((txn) async {
      final role = await getById(id, txn);
      if (role == null || role.builtin) {
        throw HMBException('Standard roles cannot be deleted.');
      }
      final used = await txn.rawQuery(
        'SELECT 1 FROM contact WHERE default_role_id = ? '
        'UNION ALL SELECT 1 FROM job_party WHERE role_id = ? LIMIT 1',
        [id, id],
      );
      if (used.isNotEmpty) {
        throw HMBException(
          'This role is in use. Reassign its contacts and jobs first.',
        );
      }
      await txn.delete('contact_role', where: 'id = ?', whereArgs: [id]);
    });
  }
}

class ContactRoleUsage {
  final List<Contact> contacts;
  final List<({Job job, Contact contact})> assignments;
  const ContactRoleUsage({required this.contacts, required this.assignments});
  bool get isEmpty => contacts.isEmpty && assignments.isEmpty;
}

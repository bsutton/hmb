import 'package:sqflite_common/sqlite_api.dart';

import '../entity/contact_role.dart';
import '../entity/job.dart';
import '../entity/job_party.dart';
import '../util/dart/exceptions.dart';
import 'dao.dart';
import 'dao_contact.dart';
import 'dao_contact_role.dart';
import 'dao_job.dart';
import 'job_billing_contact.dart';

class DaoJobParty {
  Database get _db => DatabaseHelper.instance.database;

  Future<List<JobParty>> getByJob(int jobId, [Transaction? transaction]) async {
    final rows = await (transaction ?? _db).query(
      'job_party',
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'role_id, id',
    );
    final parties = <JobParty>[];
    for (final row in rows) {
      final contact = await DaoContact().getById(
        row['contact_id']! as int,
        transaction,
      );
      final role = await DaoContactRole().getById(
        row['role_id']! as int,
        transaction,
      );
      if (contact != null && role != null) {
        parties.add(
          JobParty(id: row['id']! as int, contact: contact, role: role),
        );
      }
    }
    return parties;
  }

  Future<void> save({
    required int jobId,
    required int contactId,
    required int roleId,
    int? assignmentId,
    bool replaceSingleton = false,
    Transaction? transaction,
  }) async {
    Future<void> saveInTransaction(Transaction txn) async {
      final role = await DaoContactRole().getById(roleId, txn);
      final job = await DaoJob().getById(jobId, txn);
      if (role == null ||
          await DaoContact().getById(contactId, txn) == null ||
          job == null) {
        throw HMBException('Select a valid contact and role.');
      }
      if (roleId == ContactRole.billing &&
          !(await billingContactsForCustomer(
            job.billingCustomerId,
            txn,
          )).any((contact) => contact.id == contactId)) {
        throw HMBException(
          'Choose a contact belonging to the Bill To customer. '
          'Change the Bill To customer in Billing first if needed.',
        );
      }
      final previous = assignmentId == null
          ? <Map<String, Object?>>[]
          : await txn.query(
              'job_party',
              where: 'id = ? AND job_id = ?',
              whereArgs: [assignmentId, jobId],
            );
      if (role.singlePerJob) {
        final existing = await txn.query(
          'job_party',
          where: 'job_id = ? AND role_id = ? AND id != ?',
          whereArgs: [jobId, roleId, assignmentId ?? -1],
        );
        if (existing.isNotEmpty && !replaceSingleton) {
          throw HMBException('This job already has a ${role.name}.');
        }
        if (replaceSingleton) {
          await txn.delete(
            'job_party',
            where: 'job_id = ? AND role_id = ? AND id != ?',
            whereArgs: [jobId, roleId, assignmentId ?? -1],
          );
        }
      }
      final values = {
        'job_id': jobId,
        'contact_id': contactId,
        'role_id': roleId,
      };
      if (assignmentId == null) {
        await txn.insert('job_party', values);
      } else {
        final count = await txn.update(
          'job_party',
          values,
          where: 'id = ? AND job_id = ?',
          whereArgs: [assignmentId, jobId],
        );
        if (count != 1) {
          throw HMBException('This party assignment no longer exists.');
        }
      }
      if (roleId == ContactRole.billing ||
          previous.any((row) => row['role_id'] == ContactRole.billing)) {
        // A deliberate billing choice supersedes the migration fallback.
        final billingValues = <String, Object?>{
          'legacy_billing_contact_id': null,
        };
        await txn.update(
          'job',
          billingValues,
          where: 'id = ?',
          whereArgs: [jobId],
        );
      }
      await _projectLegacyFields(jobId, txn);
    }

    if (transaction != null) {
      await saveInTransaction(transaction);
    } else {
      await _db.transaction(saveInTransaction);
      Dao.notifier(DaoJob(), jobId);
    }
  }

  Future<void> delete(int jobId, int assignmentId) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'job_party',
        where: 'id = ? AND job_id = ?',
        whereArgs: [assignmentId, jobId],
      );
      if (rows.isNotEmpty && rows.first['role_id'] == ContactRole.billing) {
        await txn.update(
          'job',
          {'legacy_billing_contact_id': null},
          where: 'id = ?',
          whereArgs: [jobId],
        );
      }
      await txn.delete(
        'job_party',
        where: 'id = ? AND job_id = ?',
        whereArgs: [assignmentId, jobId],
      );
      await _projectLegacyFields(jobId, txn);
    });
    Dao.notifier(DaoJob(), jobId);
  }

  /// Compatibility boundary for existing job creators and callers. Only
  /// changed legacy fields affect assignments; unrelated edits retain roles.
  Future<void> syncLegacyFields(Job job, Job? previous, Transaction txn) async {
    final fields = <int, (int?, int?)>{
      ContactRole.primary: (job.contactId, previous?.contactId),
      ContactRole.billing: (job.billingContactId, previous?.billingContactId),
      ContactRole.referrer: (
        job.referrerContactId,
        previous?.referrerContactId,
      ),
      ContactRole.tenant: (job.tenantContactId, previous?.tenantContactId),
    };
    for (final entry in fields.entries) {
      final (current, old) = entry.value;
      if (previous != null && current == old) {
        continue;
      }
      await txn.delete(
        'job_party',
        where: 'job_id = ? AND role_id = ?',
        whereArgs: [job.id, entry.key],
      );
      if (current != null) {
        await txn.insert('job_party', {
          'job_id': job.id,
          'contact_id': current,
          'role_id': entry.key,
        });
      }
    }
  }

  Future<void> _projectLegacyFields(int jobId, Transaction txn) async {
    final values = <String, Object?>{
      'modified_date': DateTime.now().toIso8601String(),
    };
    for (final entry in const {
      'contact_id': ContactRole.primary,
      'billing_contact_id': ContactRole.billing,
      'referrer_contact_id': ContactRole.referrer,
      'tenant_contact_id': ContactRole.tenant,
    }.entries) {
      final rows = await txn.query(
        'job_party',
        columns: ['contact_id'],
        where: 'job_id = ? AND role_id = ?',
        whereArgs: [jobId, entry.value],
        orderBy: 'id',
        limit: 1,
      );
      values[entry.key] = rows.isEmpty ? null : rows.first['contact_id'];
    }
    await txn.update('job', values, where: 'id = ?', whereArgs: [jobId]);
  }
}

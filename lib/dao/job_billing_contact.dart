import 'package:sqflite_common/sqlite_api.dart';

import '../entity/contact.dart';
import '../entity/job.dart';
import 'dao.dart';
import 'dao_contact.dart';
import 'dao_customer.dart';

enum JobBillingContactSource {
  explicit('Selected for this job'),
  preserved('Preserved from the existing billing arrangement'),
  customerDefault("Using the Bill To customer's default billing contact"),
  primary("Using the job's Primary Contact from the Bill To customer"),
  onlyContact('Using the only job contact belonging to the Bill To customer'),
  missing('Select a billing contact before invoicing');

  const JobBillingContactSource(this.description);
  final String description;
}

class ResolvedJobBillingContact {
  final Contact? contact;
  final JobBillingContactSource source;
  const ResolvedJobBillingContact(this.contact, this.source);
}

/// Contacts attached to the billing account, including its configured default.
Future<List<Contact>> billingContactsForCustomer(
  int? customerId, [
  Transaction? transaction,
]) async {
  final contacts = await DaoContact().getByCustomer(customerId, transaction);
  final customer = await DaoCustomer().getById(customerId, transaction);
  final defaultContact = await DaoContact().getById(
    customer?.billingContactId,
    transaction,
  );
  if (defaultContact != null &&
      !contacts.any((contact) => contact.id == defaultContact.id)) {
    contacts.add(defaultContact);
  }
  return contacts;
}

Future<ResolvedJobBillingContact> resolveJobBillingContact(
  Job job, [
  Transaction? transaction,
]) async {
  final dao = DaoContact();
  final customer = await DaoCustomer().getById(
    job.billingCustomerId,
    transaction,
  );
  final eligibleIds = (await billingContactsForCustomer(
    job.billingCustomerId,
    transaction,
  )).map((contact) => contact.id).toSet();
  for (final candidate in [
    (job.billingContactId, JobBillingContactSource.explicit),
    (job.legacyBillingContactId, JobBillingContactSource.preserved),
    (customer?.billingContactId, JobBillingContactSource.customerDefault),
    (job.contactId, JobBillingContactSource.primary),
  ]) {
    if (candidate.$2 == JobBillingContactSource.primary &&
        !eligibleIds.contains(candidate.$1)) {
      continue;
    }
    final contact = await dao.getById(candidate.$1, transaction);
    if (contact != null) {
      return ResolvedJobBillingContact(contact, candidate.$2);
    }
  }
  final rows = await (transaction ?? DatabaseHelper.instance.database).rawQuery(
    'SELECT DISTINCT contact_id FROM job_party WHERE job_id = ?',
    [job.id],
  );
  final eligibleRows = rows
      .where((row) => eligibleIds.contains(row['contact_id']))
      .toList();
  if (eligibleRows.length == 1) {
    final contact = await dao.getById(
      eligibleRows.single['contact_id']! as int,
      transaction,
    );
    if (contact != null) {
      return ResolvedJobBillingContact(
        contact,
        JobBillingContactSource.onlyContact,
      );
    }
  }
  return const ResolvedJobBillingContact(null, JobBillingContactSource.missing);
}

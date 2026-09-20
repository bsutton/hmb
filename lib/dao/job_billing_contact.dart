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
  primary("Using the job's Primary Contact"),
  onlyContact('Using the only contact on this job'),
  missing('Select a billing contact before invoicing');

  const JobBillingContactSource(this.description);
  final String description;
}

class ResolvedJobBillingContact {
  final Contact? contact;
  final JobBillingContactSource source;
  const ResolvedJobBillingContact(this.contact, this.source);
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
  for (final candidate in [
    (job.billingContactId, JobBillingContactSource.explicit),
    (job.legacyBillingContactId, JobBillingContactSource.preserved),
    (customer?.billingContactId, JobBillingContactSource.customerDefault),
    (job.contactId, JobBillingContactSource.primary),
  ]) {
    final contact = await dao.getById(candidate.$1, transaction);
    if (contact != null) {
      return ResolvedJobBillingContact(contact, candidate.$2);
    }
  }
  final rows = await (transaction ?? DatabaseHelper.instance.database).rawQuery(
    'SELECT DISTINCT contact_id FROM job_party WHERE job_id = ?',
    [job.id],
  );
  if (rows.length == 1) {
    final contact = await dao.getById(
      rows.single['contact_id']! as int,
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

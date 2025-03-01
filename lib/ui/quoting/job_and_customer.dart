// quote_list_screen.dart

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';

/// Helper class to load both Job and Customer details for a given Quote.
class JobAndCustomer {
  JobAndCustomer({
    required this.job,
    required this.customer,
    required this.contact,
  });
  final Job job;
  final Customer customer;
  final Contact? contact;
  static Future<JobAndCustomer> fromQuote(Quote quote) async {
    final job = await DaoJob().getById(quote.jobId);
    if (job == null) {
      throw Exception('Job not found for Quote ${quote.id}');
    }
    final customer = await DaoCustomer().getById(job.customerId);
    if (customer == null) {
      throw Exception('Customer not found for Job ${job.id}');
    }

    final contact = await DaoContact().getPrimaryForJob(job.id);
    return JobAndCustomer(job: job, customer: customer, contact: contact);
  }
}

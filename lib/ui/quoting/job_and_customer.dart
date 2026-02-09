/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// quote_list_screen.dart

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';

/// Helper class to load both Job and Customer details for a given Quote.
class JobAndCustomer {
  final Job job;
  final Customer customer;
  final Contact? primaryContact;
  final Contact? billingContact;

  JobAndCustomer({
    required this.job,
    required this.customer,
    required this.primaryContact,
    required this.billingContact,
  });

  static Future<JobAndCustomer> fromQuote(Quote quote) async {
    final job = await DaoJob().getById(quote.jobId);
    if (job == null) {
      throw Exception('Job not found for Quote ${quote.id}');
    }
    final customer = await DaoCustomer().getById(job.customerId);
    if (customer == null) {
      throw Exception('Customer not found for Job ${job.id}');
    }

    final primaryContact = await DaoContact().getPrimaryForJob(job.id);
    final billingContact = await DaoContact().getBillingContactByJob(job);
    return JobAndCustomer(
      job: job,
      customer: customer,
      primaryContact: primaryContact,
      billingContact: billingContact,
    );
  }
}

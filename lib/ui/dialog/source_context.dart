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

import '../../dao/dao.g.dart';
import '../../entity/contact.dart';
import '../../entity/customer.dart';
import '../../entity/invoice.dart';
import '../../entity/job.dart';
import '../../entity/job_activity.dart';
import '../../entity/site.dart';
import '../../entity/supplier.dart';
import '../../util/dart/local_date.dart';

class SourceContext {
  Customer? customer;
  Job? job;
  Contact? contact;
  Supplier? supplier;
  Site? site;
  Invoice? invoice;
  String? delayPeriod;
  LocalDate? originalDate;
  JobActivity? jobActivity;
  final bool inferContact;

  SourceContext({
    this.customer,
    this.job,
    this.contact,
    this.supplier,
    this.site,
    this.invoice,
    this.delayPeriod,
    this.originalDate,
    this.jobActivity,
    this.inferContact = true,
  });

  /// Drafts must not write their selections back to the caller.
  SourceContext copy() => SourceContext(
    customer: customer,
    job: job,
    contact: contact,
    supplier: supplier,
    site: site,
    invoice: invoice,
    delayPeriod: delayPeriod,
    originalDate: originalDate,
    jobActivity: jobActivity,
    inferContact: inferContact,
  );

  String get recipientName => (contact?.firstName.trim().isNotEmpty ?? false)
      ? contact!.firstName.trim()
      : (contact?.fullname.trim().isNotEmpty ?? false)
      ? contact!.fullname.trim()
      : supplier?.name ?? customer?.name ?? '';

  /// Resolve only relationships that identify one context unambiguously.
  Future<void> resolveEntities() async {
    job ??= await DaoJob().getById(jobActivity?.jobId ?? invoice?.jobId);
    if (job != null) {
      customer = await DaoCustomer().getById(job!.customerId);
      if (inferContact) {
        contact ??= await DaoContact().getPrimaryForJob(job!.id);
      }
      jobActivity ??= await DaoJobActivity().getMostRecentByJob(job!.id);
    } else if (supplier == null && customer == null) {
      // A site can have several customers; it does not identify a recipient.
      if (contact != null) {
        final customers = await DaoCustomer().getByContactIds([contact!.id]);
        customer = customers.length == 1 ? customers.single : null;
      }
    }
    if (customer != null && supplier == null && inferContact) {
      contact ??= await DaoContact().getPrimaryForCustomer(customer!.id);
    }
    await resolveSite();
  }

  /// A job's site is authoritative. Customer-only messages may infer a site
  /// only when there is exactly one; never guess among several properties.
  Future<void> resolveSite() async {
    if (job != null) {
      if (site?.id != job!.siteId) {
        site = await DaoSite().getById(job!.siteId);
      }
    } else if (site == null && customer != null) {
      final sites = await DaoSite().getByCustomer(customer!.id);
      site = sites.length == 1 ? sites.single : null;
    }
  }
}

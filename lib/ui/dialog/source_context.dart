import '../../dao/dao.g.dart';
import '../../entity/contact.dart';
import '../../entity/customer.dart';
import '../../entity/invoice.dart';
import '../../entity/job.dart';
import '../../entity/job_activity.dart';
import '../../entity/site.dart';
import '../../entity/supplier.dart';
import '../../util/local_date.dart';

class SourceContext {
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
  });

  // static SourceContext create({
  //   Customer? customer,
  //   Job? job,
  //   Contact? contact,
  //   Supplier? supplier,
  //   Site? site,
  //   Invoice? invoice,
  //   String? delayPeriod,
  //   LocalDate? originalDate,
  //   JobActivity? jobActivity,
  // }) async {
  //   final sourceContext = SourceContext._(customer, job, contact, supplier,
  //       site, invoice, delayPeriod, originalDate, jobActivity);

  //   await sourceContext.resolveEntities();

  //   return sourceContext;
  // }

  Customer? customer;
  Job? job;
  Contact? contact;
  Supplier? supplier;
  Site? site;
  Invoice? invoice;
  String? delayPeriod;
  LocalDate? originalDate;
  JobActivity? jobActivity;

  /// Fetches related entities based on the provided entities.
  /// The fetching is done in a hierarchical order based on the importance
  /// of each entity type.
  Future<void> resolveEntities() async {
    var currentHash = -1;
    var newHash = -1;

    /// keep looping unti a pass results in no updates.
    do {
      currentHash = newHash;

      /// Try by job
      customer ??= await DaoCustomer().getByJob(job!.id);
      contact ??= await DaoContact().getById(job!.contactId);
      site ??= await DaoSite().getById(job!.siteId);
      jobActivity ??= await DaoJobActivity().getMostRecentByJob(job!.id);

      // try by customer
      contact ??= (await DaoContact().getByCustomer(customer!.id)).lastOrNull;
      site ??= (await DaoSite().getByCustomer(customer!.id)).firstOrNull;
      jobActivity ??= (await DaoJobActivity().getByJob(job!.id)).lastOrNull;

      // try by contact
      customer ??= await DaoCustomer().getByContact(contact!.id);
      // try by site
      customer ??= await DaoCustomer().getBySite(site!.id);
    } while (currentHash != (newHash = _buildHash()));
  }

  int _buildHash() => Object.hashAll([
    customer,
    job,
    contact,
    supplier,
    site,
    invoice,
    delayPeriod,
    originalDate,
    jobActivity,
  ]);
}

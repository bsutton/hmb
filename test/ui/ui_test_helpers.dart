import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:money2/money2.dart';

Future<Job> createJobWithCustomer({
  required BillingType billingType,
  required Money hourlyRate,
  Money? bookingFee,
  String summary = 'Test Job',
}) async {
  final contactId = await DaoContact().insert(
    Contact.forInsert(
      firstName: 'Pat',
      surname: 'Tester',
      mobileNumber: '0400000000',
      landLine: '',
      officeNumber: '',
      emailAddress: 'pat@example.com',
    ),
  );
  final customerId = await DaoCustomer().insert(
    Customer.forInsert(
      name: 'Test Customer',
      description: 'Customer for widget tests',
      disbarred: false,
      customerType: CustomerType.residential,
      hourlyRate: hourlyRate,
      billingContactId: contactId,
    ),
  );
  final siteId = await DaoSite().insert(
    Site.forInsert(
      addressLine1: '1 Test St',
      addressLine2: '',
      suburb: 'Testville',
      state: 'TS',
      postcode: '1234',
      accessDetails: null,
    ),
  );

  final jobId = await DaoJob().insert(
    Job.forInsert(
      customerId: customerId,
      summary: summary,
      description: 'Widget test job',
      siteId: siteId,
      contactId: contactId,
      status: JobStatus.startingStatus,
      hourlyRate: hourlyRate,
      bookingFee: bookingFee,
      billingType: billingType,
      billingContactId: contactId,
    ),
  );

  return (await DaoJob().getById(jobId))!;
}

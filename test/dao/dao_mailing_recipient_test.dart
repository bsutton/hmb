import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/tools/mailings/label_layout.dart';
import 'package:hmb/ui/tools/mailings/mailing_label_pdf.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('mailing recipients exclude disbarred customers', () async {
    final good = await _insertCustomer(name: 'Good Customer');
    final bad = await _insertCustomer(name: 'Bad Customer', disbarred: true);

    final mailing = Mailing.forInsert(
      name: 'Fridge magnets',
      labelLayoutId: LabelLayout.all.first.id,
    );
    await DaoMailing().insert(mailing);
    await DaoMailingRecipient().populateForMailing(mailing.id);

    final recipients = await DaoMailingRecipient().getByMailing(mailing.id);

    expect(
      recipients.map((recipient) => recipient.customerId),
      contains(good.id),
    );
    expect(
      recipients.map((recipient) => recipient.customerId),
      isNot(contains(bad.id)),
    );
  });

  test('mailing recipients exclude opt-out customers', () async {
    final included = await _insertCustomer(name: 'Included Customer');
    final optedOut = await _insertCustomer(
      name: 'Opted Out Customer',
      excludeFromMailings: true,
    );

    final mailing = Mailing.forInsert(
      name: 'Fridge magnets',
      labelLayoutId: LabelLayout.all.first.id,
    );
    await DaoMailing().insert(mailing);
    await DaoMailingRecipient().populateForMailing(mailing.id);

    final recipients = await DaoMailingRecipient().getByMailing(mailing.id);
    final customerIds = recipients.map((recipient) => recipient.customerId);

    expect(customerIds, contains(included.id));
    expect(customerIds, isNot(contains(optedOut.id)));
  });

  test('mailing recipients exclude the stock customer', () async {
    final normal = await _insertCustomer(name: 'Normal Customer');
    final stockJob = await DaoJob().getStockJob();
    expect(stockJob, isNotNull);

    final mailing = Mailing.forInsert(
      name: 'Fridge magnets',
      labelLayoutId: LabelLayout.all.first.id,
    );
    await DaoMailing().insert(mailing);
    await DaoMailingRecipient().populateForMailing(mailing.id);

    final recipients = await DaoMailingRecipient().getByMailing(mailing.id);
    final customerIds = recipients.map((recipient) => recipient.customerId);

    expect(customerIds, contains(normal.id));
    expect(customerIds, isNot(contains(stockJob!.customerId)));
  });

  test('mailing recipient snapshots primary contact and named site', () async {
    final customer = await _insertCustomer(
      name: 'Customer Trading Name',
      firstName: 'Pat',
      surname: 'Smith',
      siteName: 'Home',
    );

    final mailing = Mailing.forInsert(
      name: 'Fridge magnets',
      labelLayoutId: LabelLayout.all.first.id,
    );
    await DaoMailing().insert(mailing);
    await DaoMailingRecipient().populateForMailing(mailing.id);

    final recipient = (await DaoMailingRecipient().getByMailing(
      mailing.id,
    )).singleWhere((recipient) => recipient.customerId == customer.id);

    expect(recipient.contactName, 'Pat Smith');
    expect(recipient.customerName, 'Customer Trading Name');
    expect(recipient.siteName, 'Home');
    expect(recipient.hasAddress, isTrue);
  });

  test('label pdf can be generated for ready recipients', () async {
    final customer = await _insertCustomer(name: 'Label Customer');
    final mailing = Mailing.forInsert(
      name: 'Fridge magnets',
      labelLayoutId: LabelLayout.all.first.id,
    );
    await DaoMailing().insert(mailing);
    await DaoMailingRecipient().populateForMailing(mailing.id);
    final recipient = (await DaoMailingRecipient().getByMailing(
      mailing.id,
    )).singleWhere((recipient) => recipient.customerId == customer.id);

    final bytes = await buildMailingLabelPdfBytes(
      recipients: [recipient],
      layout: LabelLayout.all.first,
    );

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('suburb-only sites are not ready for mailing', () async {
    final customer = await _insertCustomer(
      name: 'Incomplete Address Customer',
      addressLine1: '',
    );
    final mailing = Mailing.forInsert(
      name: 'Fridge magnets',
      labelLayoutId: LabelLayout.all.first.id,
    );
    await DaoMailing().insert(mailing);
    await DaoMailingRecipient().populateForMailing(mailing.id);

    final recipient = (await DaoMailingRecipient().getByMailing(
      mailing.id,
    )).singleWhere((recipient) => recipient.customerId == customer.id);

    expect(recipient.hasAddress, isFalse);
    expect(recipient.hasPartialAddress, isTrue);
    expect(recipient.selected, isFalse);
    expect(await DaoMailingRecipient().getRouteReady(mailing.id), isEmpty);

    await DaoMailingRecipient().setAllSelected(
      mailingId: mailing.id,
      selected: true,
    );
    final updated = (await DaoMailingRecipient().getByMailing(
      mailing.id,
    )).singleWhere((recipient) => recipient.customerId == customer.id);

    expect(updated.selected, isFalse);

    await DaoMailingRecipient().update(updated.copyWith(selected: true));
    await DaoMailingRecipient().deselectUnmailableRecipients(mailing.id);
    final normalised = (await DaoMailingRecipient().getByMailing(
      mailing.id,
    )).singleWhere((recipient) => recipient.customerId == customer.id);

    expect(normalised.selected, isFalse);
  });

  test('street-only addresses are not ready for mailing', () async {
    final customer = await _insertCustomer(
      name: 'Street Only Customer',
      addressLine1: 'Upper Heidelberg Road',
      suburb: 'Ivanhoe',
    );
    final mailing = Mailing.forInsert(
      name: 'Fridge magnets',
      labelLayoutId: LabelLayout.all.first.id,
    );
    await DaoMailing().insert(mailing);
    await DaoMailingRecipient().populateForMailing(mailing.id);

    final recipient = (await DaoMailingRecipient().getByMailing(
      mailing.id,
    )).singleWhere((recipient) => recipient.customerId == customer.id);

    expect(recipient.hasAddress, isFalse);
    expect(recipient.hasPartialAddress, isTrue);
    expect(recipient.selected, isFalse);
    expect(await DaoMailingRecipient().getRouteReady(mailing.id), isEmpty);
  });

  test('excluded recipients are not selected or routed', () async {
    final customer = await _insertCustomer(name: 'Excluded Customer');
    final mailing = Mailing.forInsert(
      name: 'Fridge magnets',
      labelLayoutId: LabelLayout.all.first.id,
    );
    await DaoMailing().insert(mailing);
    await DaoMailingRecipient().populateForMailing(mailing.id);

    final recipient = (await DaoMailingRecipient().getByMailing(
      mailing.id,
    )).singleWhere((recipient) => recipient.customerId == customer.id);

    expect(recipient.selected, isTrue);
    expect(await DaoMailingRecipient().getRouteReady(mailing.id), isNotEmpty);

    await DaoMailingRecipient().update(
      recipient.copyWith(selected: false, excluded: true),
    );
    expect(await DaoMailingRecipient().getRouteReady(mailing.id), isEmpty);

    await DaoMailingRecipient().setAllSelected(
      mailingId: mailing.id,
      selected: true,
    );
    final updated = (await DaoMailingRecipient().getByMailing(
      mailing.id,
    )).singleWhere((recipient) => recipient.customerId == customer.id);

    expect(updated.excluded, isTrue);
    expect(updated.selected, isFalse);
  });
}

Future<Customer> _insertCustomer({
  required String name,
  bool disbarred = false,
  bool excludeFromMailings = false,
  String firstName = 'Alex',
  String surname = 'Resident',
  String? siteName,
  String addressLine1 = '1 Main St',
  String suburb = 'Town',
}) async {
  final customer = Customer.forInsert(
    name: name,
    description: '',
    disbarred: disbarred,
    excludeFromMailings: excludeFromMailings,
    customerType: CustomerType.residential,
    hourlyRate: MoneyEx.zero,
    billingContactId: null,
  );
  await DaoCustomer().insert(customer);

  final contact = Contact.forInsert(
    firstName: firstName,
    surname: surname,
    mobileNumber: '0400000000',
    landLine: '',
    officeNumber: '',
    emailAddress: '${name.toLowerCase().replaceAll(' ', '.')}@example.com',
  );
  await DaoContact().insert(contact);
  await DaoContactCustomer().insertJoin(contact, customer);
  await DaoContactCustomer().setAsPrimary(contact, customer);

  final site = Site.forInsert(
    name: siteName,
    addressLine1: addressLine1,
    addressLine2: '',
    suburb: suburb,
    state: 'VIC',
    postcode: '3000',
    accessDetails: '',
  );
  await DaoSite().insert(site);
  await DaoSiteCustomer().insertJoin(site, customer);

  final savedCustomer = customer.copyWith(billingContactId: contact.id);
  await DaoCustomer().update(savedCustomer);
  return savedCustomer;
}

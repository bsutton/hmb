import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
    final system = await DaoSystem().get();
    await DaoSystem().update(
      system.copyWith(
        invoiceLineRevenueAccountCode: '200',
        invoiceLineInventoryItemCode: 'ITEM-1',
      ),
    );
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('suppresses offset pair when return links to source '
      'and both are on same invoice', () async {
    final fixture = await _createFixture();
    final invoice = await _createInvoice(fixture.job, fixture.contact);
    final group = await _createLineGroup(invoice, 'Task');

    final materialLineId = await DaoInvoiceLine().insert(
      InvoiceLine.forInsert(
        invoiceId: invoice.id,
        invoiceLineGroupId: group.id,
        description: 'Material: Paint',
        quantity: Fixed.one,
        unitPrice: MoneyEx.fromInt(1125),
        lineTotal: MoneyEx.fromInt(1125),
      ),
    );
    final sourceItem = await _insertMaterialTaskItem(fixture.task);
    await DaoTaskItem().markAsBilled(sourceItem, materialLineId);

    final returnedLineId = await DaoInvoiceLine().insert(
      InvoiceLine.forInsert(
        invoiceId: invoice.id,
        invoiceLineGroupId: group.id,
        description: 'Returned: Paint',
        quantity: Fixed.one,
        unitPrice: -MoneyEx.fromInt(1125),
        lineTotal: -MoneyEx.fromInt(1125),
      ),
    );
    final returnItem = await _insertReturnTaskItem(sourceItem);
    await DaoTaskItem().markAsBilled(returnItem, returnedLineId);

    await DaoInvoiceLine().insert(
      InvoiceLine.forInsert(
        invoiceId: invoice.id,
        invoiceLineGroupId: group.id,
        description: 'Material: Sealant',
        quantity: Fixed.one,
        unitPrice: MoneyEx.dollars(8),
        lineTotal: MoneyEx.dollars(8),
      ),
    );

    final xeroInvoice = await invoice.toXeroInvoice(invoice);

    expect(xeroInvoice.lineItems.length, equals(1));
    expect(
      xeroInvoice.lineItems.single.description,
      equals('Material: Sealant'),
    );
  });

  test('keeps lines when return links to source '
      'but they are on different invoices', () async {
    final fixture = await _createFixture();
    final invoiceA = await _createInvoice(fixture.job, fixture.contact);
    final invoiceB = await _createInvoice(fixture.job, fixture.contact);
    final groupA = await _createLineGroup(invoiceA, 'A');
    final groupB = await _createLineGroup(invoiceB, 'B');

    final materialLineId = await DaoInvoiceLine().insert(
      InvoiceLine.forInsert(
        invoiceId: invoiceA.id,
        invoiceLineGroupId: groupA.id,
        description: 'Material: Paint',
        quantity: Fixed.one,
        unitPrice: MoneyEx.fromInt(1125),
        lineTotal: MoneyEx.fromInt(1125),
      ),
    );
    final sourceItem = await _insertMaterialTaskItem(fixture.task);
    await DaoTaskItem().markAsBilled(sourceItem, materialLineId);

    final returnLineId = await DaoInvoiceLine().insert(
      InvoiceLine.forInsert(
        invoiceId: invoiceB.id,
        invoiceLineGroupId: groupB.id,
        description: 'Returned: Paint',
        quantity: Fixed.one,
        unitPrice: -MoneyEx.fromInt(1125),
        lineTotal: -MoneyEx.fromInt(1125),
      ),
    );
    final returnItem = await _insertReturnTaskItem(sourceItem);
    await DaoTaskItem().markAsBilled(returnItem, returnLineId);

    final xeroA = await invoiceA.toXeroInvoice(invoiceA);
    final xeroB = await invoiceB.toXeroInvoice(invoiceB);

    expect(xeroA.lineItems.length, equals(1));
    expect(xeroA.lineItems.single.lineTotal, equals(MoneyEx.fromInt(1125)));

    expect(xeroB.lineItems.length, equals(1));
    expect(xeroB.lineItems.single.lineTotal, equals(-MoneyEx.fromInt(1125)));
    expect(xeroB.lineItems.single.unitAmount, equals(MoneyEx.fromInt(1125)));
    expect(xeroB.lineItems.single.quantity, equals(-Fixed.one));
  });
}

class _Fixture {
  final Contact contact;
  final Job job;
  final Task task;

  _Fixture(this.contact, this.job, this.task);
}

Future<_Fixture> _createFixture() async {
  final contact = Contact.forInsert(
    firstName: 'Pat',
    surname: 'Customer',
    mobileNumber: '',
    landLine: '',
    officeNumber: '',
    emailAddress: 'pat@example.com',
  );
  await DaoContact().insert(contact);

  final customer = Customer.forInsert(
    name: 'Pat Customer',
    description: '',
    disbarred: false,
    customerType: CustomerType.residential,
    hourlyRate: MoneyEx.zero,
    billingContactId: null,
  );
  await DaoCustomer().insert(customer);
  await DaoContactCustomer().insertJoin(contact, customer);
  await DaoCustomer().update(customer.copyWith(billingContactId: contact.id));

  final job = Job.forInsert(
    customerId: customer.id,
    summary: 'Offset Test Job',
    description: 'desc',
    siteId: null,
    contactId: contact.id,
    status: JobStatus.startingStatus,
    hourlyRate: MoneyEx.dollars(100),
    bookingFee: MoneyEx.zero,
    billingContactId: contact.id,
  );
  await DaoJob().insert(job);

  final task = Task.forInsert(
    jobId: job.id,
    name: 'Task A',
    description: '',
    status: TaskStatus.awaitingApproval,
  );
  await DaoTask().insert(task);

  return _Fixture(contact, job, task);
}

Future<Invoice> _createInvoice(Job job, Contact contact) async {
  final invoice = Invoice.forInsert(
    jobId: job.id,
    dueDate: LocalDate.today(),
    totalAmount: MoneyEx.zero,
    billingContactId: contact.id,
  );
  await DaoInvoice().insert(invoice);
  return invoice;
}

Future<InvoiceLineGroup> _createLineGroup(Invoice invoice, String name) async {
  final group = InvoiceLineGroup.forInsert(invoiceId: invoice.id, name: name);
  await DaoInvoiceLineGroup().insert(group);
  return group;
}

Future<TaskItem> _insertMaterialTaskItem(Task task) async {
  final item = TaskItem.forInsert(
    taskId: task.id,
    description: 'Paint',
    purpose: '',
    itemType: TaskItemType.materialsBuy,
    estimatedMaterialUnitCost: MoneyEx.fromInt(1125),
    estimatedMaterialQuantity: Fixed.one,
    actualMaterialUnitCost: MoneyEx.fromInt(1125),
    actualMaterialQuantity: Fixed.one,
    chargeMode: ChargeMode.calculated,
    margin: Percentage.zero,
    completed: true,
    measurementType: MeasurementType.length,
    dimension1: Fixed.zero,
    dimension2: Fixed.zero,
    dimension3: Fixed.zero,
    units: Units.m,
    url: '',
    labourEntryMode: LabourEntryMode.hours,
  );
  await DaoTaskItem().insert(item);
  return item;
}

Future<TaskItem> _insertReturnTaskItem(TaskItem sourceItem) async {
  final returnItem = sourceItem.forReturn(Fixed.one, MoneyEx.fromInt(1125));
  await DaoTaskItem().insert(returnItem);
  return returnItem;
}

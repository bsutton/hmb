import 'package:money2/money2.dart';

import '../dao/dao_contact.dart';
import '../dao/dao_invoice_line.dart';
import '../dao/dao_job.dart';
import '../invoicing/xero/models/xero_invoice.dart';
import '../util/exceptions.dart';
import 'entity.dart';

class Invoice extends Entity<Invoice> {
  Invoice({
    required super.id,
    required this.jobId,
    required this.totalAmount,
    required super.createdDate,
    required super.modifiedDate,
    required this.invoiceNum,
    this.externalInvoiceId,
  }) : super();

  Invoice.forInsert({
    required this.jobId,
    required this.totalAmount,
  }) : super.forInsert();

  Invoice.forUpdate({
    required super.entity,
    required this.jobId,
    required this.totalAmount,
    required this.invoiceNum,
    this.externalInvoiceId,
  }) : super.forUpdate();

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice(
        id: map['id'] as int,
        jobId: map['job_id'] as int,
        totalAmount: Money.fromInt(map['total_amount'] as int, isoCode: 'AUD'),
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
        invoiceNum: map['invoice_num'] as String?,
        externalInvoiceId: map['external_invoice_id'] as String?,
      );

  int jobId;
  Money totalAmount;
  String? invoiceNum;
  String? externalInvoiceId;

  Invoice copyWith({
    int? id,
    int? jobId,
    Money? totalAmount,
    DateTime? createdDate,
    DateTime? modifiedDate,
    String? invoiceNum,
    String? externalInvoiceId,
  }) =>
      Invoice(
        id: id ?? this.id,
        jobId: jobId ?? this.jobId,
        totalAmount: totalAmount ?? this.totalAmount,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate ?? this.modifiedDate,
        invoiceNum: invoiceNum ?? this.invoiceNum,
        externalInvoiceId: externalInvoiceId ?? this.externalInvoiceId,
      );

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'job_id': jobId,
        'total_amount': totalAmount.minorUnits.toInt(),
        'created_date': createdDate.toIso8601String(),
        'modified_date': modifiedDate.toIso8601String(),
        'invoice_num': invoiceNum,
        'external_invoice_id': externalInvoiceId,
      };

  Future<XeroInvoice> toXeroInvoice(Invoice invoice) async {
    final job = await DaoJob().getById(invoice.jobId);

    final contact = await DaoContact().getForJob(job?.id);
    if (contact == null) {
      throw InvoiceException(
          '''You must assign a Contact to the Job before you can upload an invoice''');
    }
    final xeroContact = contact.toXeroContact();

    final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);

    final xeroInvoice = XeroInvoice(
        reference: job!.summary,
        type: 'ACCREC',
        contact: xeroContact,
        issueDate: invoice.createdDate,
        // TODO(bsutton): make due date configurable
        dueDate: invoice.createdDate.add(const Duration(days: 3)),
        lineItems: invoiceLines.map((line) => line.toXeroLineItem()).toList(),
        lineAmountTypes: 'Inclusive'); // All amounts are inclusive of tax.
    return xeroInvoice;
  }
}

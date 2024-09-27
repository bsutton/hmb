import 'package:money2/money2.dart';

import '../dao/dao_contact.dart';
import '../dao/dao_invoice_line.dart';
import '../dao/dao_job.dart';
import '../invoicing/xero/models/xero_invoice.dart';
import '../util/exceptions.dart';
import '../util/local_date.dart';
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
    LocalDate? dueDate, // New dueDate field
  }) : super() {
    this.dueDate = dueDate ??
        LocalDate.fromDateTime(createdDate.add(const Duration(days: 1)));
  }

  Invoice.forInsert({
    required this.jobId,
    required this.dueDate, // New dueDate field
    required this.totalAmount,
  }) : super.forInsert();

  Invoice.forUpdate({
    required super.entity,
    required this.jobId,
    required this.totalAmount,
    required this.invoiceNum,
    required this.dueDate, // New dueDate field
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
        dueDate: map['due_date'] != null
            ? const LocalDateConverter().fromJson(map['due_date'] as String)
            : null, // Handle new dueDate field
      );

  int jobId;
  Money totalAmount;
  String? invoiceNum;
  String? externalInvoiceId;
  late LocalDate dueDate; // New dueDate field

  String get bestNumber => externalInvoiceId ?? invoiceNum ?? '$id';

  Invoice copyWith({
    int? id,
    int? jobId,
    Money? totalAmount,
    DateTime? createdDate,
    DateTime? modifiedDate,
    String? invoiceNum,
    String? externalInvoiceId,
    LocalDate? dueDate, // Add new dueDate field
  }) =>
      Invoice(
        id: id ?? this.id,
        jobId: jobId ?? this.jobId,
        totalAmount: totalAmount ?? this.totalAmount,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate ?? this.modifiedDate,
        invoiceNum: invoiceNum ?? this.invoiceNum,
        externalInvoiceId: externalInvoiceId ?? this.externalInvoiceId,
        dueDate: dueDate ?? this.dueDate, // Handle new dueDate field
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
        'due_date':
            const LocalDateConverter().toJson(dueDate), // Add dueDate to map
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
        issueDate: LocalDate.fromDateTime(invoice.createdDate),
        dueDate: invoice.dueDate,
        lineItems: invoiceLines.map((line) => line.toXeroLineItem()).toList(),
        lineAmountTypes: 'Inclusive'); // All amounts are inclusive of tax.
    return xeroInvoice;
  }
}

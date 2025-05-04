import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../api/xero/models/xero_invoice.dart';
import '../dao/dao_contact.dart';
import '../dao/dao_invoice_line.dart';
import '../dao/dao_job.dart';
import '../util/exceptions.dart';
import '../util/local_date.dart';
import 'entity.dart';
import 'invoice_line.dart';

class Invoice extends Entity<Invoice> {
  Invoice({
    required super.id,
    required this.jobId,
    required this.totalAmount,
    required super.createdDate,
    required super.modifiedDate,
    required this.invoiceNum,
    required this.billingContactId,
    this.externalInvoiceId,
    LocalDate? dueDate,
    this.sent = false,
  }) : super() {
    this.dueDate =
        dueDate ??
        LocalDate.fromDateTime(createdDate.add(const Duration(days: 1)));
  }

  Invoice.forInsert({
    required this.jobId,
    required this.dueDate,
    required this.totalAmount,
    required this.billingContactId,
    this.sent = false,
  }) : super.forInsert();

  Invoice.forUpdate({
    required super.entity,
    required this.jobId,
    required this.totalAmount,
    required this.invoiceNum,
    required this.dueDate,
    required this.billingContactId,
    this.externalInvoiceId,
    this.sent = false,
  }) : super.forUpdate();

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice(
    id: map['id'] as int,
    jobId: map['job_id'] as int,
    totalAmount: Money.fromInt(map['total_amount'] as int, isoCode: 'AUD'),
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
    invoiceNum: map['invoice_num'] as String?,
    externalInvoiceId: map['external_invoice_id'] as String?,
    dueDate:
        map['due_date'] != null
            ? const LocalDateConverter().fromJson(map['due_date'] as String)
            : null,
    sent: (map['sent'] as int) == 1,
    billingContactId: map['billing_contact_id'] as int?,
  );

  int jobId;
  Money totalAmount;
  String? invoiceNum;
  String? externalInvoiceId;
  late LocalDate dueDate;

  /// The invoice has been marked as sent on the remote accounting system
  /// sent invoices must be voided rather than deleted.
  bool sent;
  int? billingContactId;

  String get bestNumber => invoiceNum ?? '$id';

  Invoice copyWith({
    int? id,
    int? jobId,
    Money? totalAmount,
    DateTime? createdDate,
    DateTime? modifiedDate,
    String? invoiceNum,
    String? externalInvoiceId,
    LocalDate? dueDate,
    bool? sent,
    int? billingContactId,
  }) => Invoice(
    id: id ?? this.id,
    jobId: jobId ?? this.jobId,
    totalAmount: totalAmount ?? this.totalAmount,
    createdDate: createdDate ?? this.createdDate,
    modifiedDate: modifiedDate ?? this.modifiedDate,
    invoiceNum: invoiceNum ?? this.invoiceNum,
    externalInvoiceId: externalInvoiceId ?? this.externalInvoiceId,
    dueDate: dueDate ?? this.dueDate,
    sent: sent ?? this.sent,
    billingContactId: billingContactId ?? this.billingContactId,
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
    'due_date': const LocalDateConverter().toJson(dueDate),
    'sent': sent ? 1 : 0,
    'billing_contact_id': billingContactId,
  };

  Future<XeroInvoice> toXeroInvoice(Invoice invoice) async {
    final job = await DaoJob().getById(invoice.jobId);
    final contact = await DaoContact().getPrimaryForJob(job?.id);
    if (contact == null) {
      throw InvoiceException(
        '''You must assign a Contact to the Job before you can upload an invoice''',
      );
    }
    final xeroContact = contact.toXeroContact();

    final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);

    final xeroInvoice = XeroInvoice(
      reference: job!.summary,
      type: 'ACCREC',
      contact: xeroContact,
      issueDate: LocalDate.fromDateTime(invoice.createdDate),
      dueDate: invoice.dueDate,
      lineItems:
          invoiceLines
              .where((line) => line.status == LineStatus.normal)
              .map((line) => line.toXeroLineItem())
              .toList(),
      lineAmountTypes: 'Inclusive',
    ); // All amounts are inclusive of tax.
    return xeroInvoice;
  }

  /// true if the invoice has been uploaded to the external
  /// accounting system.
  bool isUploaded() => Strings.isNotBlank(externalInvoiceId);
}

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

import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../api/xero/models/xero_invoice.dart';
import '../api/xero/models/xero_line_item.dart';
import '../dao/dao.g.dart';
import '../util/dart/exceptions.dart';
import '../util/dart/local_date.dart';
import 'entity.dart';
import 'invoice_line.dart';

class Invoice extends Entity<Invoice> {
  int jobId;
  Money totalAmount;
  String? invoiceNum;
  String? externalInvoiceId;
  late LocalDate dueDate;

  /// The invoice has been marked as sent on the remote accounting system
  /// sent invoices must be voided rather than deleted.
  bool sent;
  bool paid;
  DateTime? paidDate;
  int? billingContactId;

  Invoice._({
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
    this.paid = false,
    this.paidDate,
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
    this.paid = false,
    this.paidDate,
  }) : super.forInsert();

  Invoice copyWith({
    int? jobId,
    Money? totalAmount,
    String? invoiceNum,
    String? externalInvoiceId,
    LocalDate? dueDate,
    bool? sent,
    bool? paid,
    DateTime? paidDate,
    int? billingContactId,
  }) => Invoice._(
    id: id,
    jobId: jobId ?? this.jobId,
    totalAmount: totalAmount ?? this.totalAmount,
    invoiceNum: invoiceNum ?? this.invoiceNum,
    externalInvoiceId: externalInvoiceId ?? this.externalInvoiceId,
    dueDate: dueDate ?? this.dueDate,
    sent: sent ?? this.sent,
    paid: paid ?? this.paid,
    paidDate: paidDate ?? this.paidDate,
    billingContactId: billingContactId ?? this.billingContactId,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  String get bestNumber => invoiceNum ?? '$id';

  Future<XeroInvoice> toXeroInvoice(Invoice invoice) async {
    final job = await DaoJob().getById(invoice.jobId);
    final contact = await DaoContact().getBillingContactByJob(job!);
    if (contact == null) {
      throw InvoiceException(
        'You must assign a Contact to the Job before you can upload an invoice',
      );
    }
    final system = await DaoSystem().get();

    if (Strings.isBlank(system.invoiceLineRevenueAccountCode) ||
        Strings.isBlank(system.invoiceLineInventoryItemCode)) {
      throw InvoiceException(
        '''
You must set the Account Code and Item Code in System | Integration before you can upload an invoice''',
      );
    }

    final xeroContact = contact.toXeroContact();

    final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
    final chargeableLines = invoiceLines.where(
      (line) => line.status == LineChargeableStatus.normal,
    );
    final filteredLines = await _suppressOffsettingLines(chargeableLines);

    final xeroInvoice = XeroInvoice(
      reference: job.summary,
      type: 'ACCREC',
      contact: xeroContact,
      issueDate: LocalDate.fromDateTime(invoice.createdDate),
      dueDate: invoice.dueDate,
      lineItems: filteredLines
          .map(
            (line) => _toXeroLineItem(
              line,
              accountCode: system.invoiceLineRevenueAccountCode!,
              itemCode: system.invoiceLineInventoryItemCode!,
            ),
          )
          .toList(),
      lineAmountTypes: 'Inclusive',
    ); // All amounts are inclusive of tax.
    return xeroInvoice;
  }

  Future<List<InvoiceLine>> _suppressOffsettingLines(
    Iterable<InvoiceLine> lines,
  ) async {
    final lineList = lines.where((line) => !line.lineTotal.isZero).toList();
    if (lineList.isEmpty) {
      return lineList;
    }

    final lineById = {for (final line in lineList) line.id: line};
    final lineIds = lineById.keys.toList();
    final billedTaskItems = await DaoTaskItem().getByInvoiceLineIds(lineIds);
    final returnItems = billedTaskItems
        .where((item) => item.isReturn && item.sourceTaskItemId != null)
        .toList();
    if (returnItems.isEmpty) {
      return lineList;
    }

    final sourceIds = returnItems
        .map((item) => item.sourceTaskItemId)
        .whereType<int>()
        .toSet()
        .toList();
    final sourceItems = await DaoTaskItem().getByIds(sourceIds);
    final sourceById = {for (final source in sourceItems) source.id: source};
    final suppressedLineIds = <int>{};

    for (final returnItem in returnItems) {
      final returnLineId = returnItem.invoiceLineId;
      final sourceId = returnItem.sourceTaskItemId;
      if (returnLineId == null || sourceId == null) {
        continue;
      }
      final sourceItem = sourceById[sourceId];
      final sourceLineId = sourceItem?.invoiceLineId;
      if (sourceLineId == null) {
        continue;
      }
      final sourceLine = lineById[sourceLineId];
      final returnLine = lineById[returnLineId];
      if (sourceLine == null || returnLine == null) {
        continue;
      }

      if ((sourceLine.lineTotal + returnLine.lineTotal).isZero) {
        suppressedLineIds
          ..add(sourceLine.id)
          ..add(returnLine.id);
      }
    }

    return lineList
        .where((line) => !suppressedLineIds.contains(line.id))
        .toList();
  }

  XeroLineItem _toXeroLineItem(
    InvoiceLine line, {
    required String accountCode,
    required String itemCode,
  }) {
    var quantity = line.quantity;
    var unitAmount = line.unitPrice;
    if (unitAmount.isNegative) {
      unitAmount = -unitAmount;
    }

    if (line.lineTotal.isNegative && quantity.compareTo(Fixed.zero) > 0) {
      quantity = -quantity;
    } else if (line.lineTotal.isPositive &&
        quantity.compareTo(Fixed.zero) < 0) {
      quantity = -quantity;
    }

    return XeroLineItem(
      description: line.description,
      quantity: quantity,
      unitAmount: unitAmount,
      lineTotal: line.lineTotal,
      accountCode: accountCode,
      itemCode: itemCode,
    );
  }

  /// true if the invoice has been uploaded to the external
  /// accounting system.
  bool isUploaded() => Strings.isNotBlank(externalInvoiceId);

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice._(
    id: map['id'] as int,
    jobId: map['job_id'] as int,
    totalAmount: Money.fromInt(map['total_amount'] as int, isoCode: 'AUD'),
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
    invoiceNum: map['invoice_num'] as String?,
    externalInvoiceId: map['external_invoice_id'] as String?,
    dueDate: map['due_date'] != null
        ? const LocalDateConverter().fromJson(map['due_date'] as String)
        : null,
    sent: (map['sent'] as int) == 1,
    paid: (map['paid'] as int? ?? 0) == 1,
    paidDate: map['paid_date'] == null
        ? null
        : DateTime.parse(map['paid_date'] as String),
    billingContactId: map['billing_contact_id'] as int?,
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
    'paid': paid ? 1 : 0,
    'paid_date': paidDate?.toIso8601String(),
    'billing_contact_id': billingContactId,
  };
}

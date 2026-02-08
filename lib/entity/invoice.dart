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

  Invoice copyWith({
    int? jobId,
    Money? totalAmount,
    String? invoiceNum,
    String? externalInvoiceId,
    LocalDate? dueDate,
    bool? sent,
    int? billingContactId,
  }) => Invoice._(
    id: id,
    jobId: jobId ?? this.jobId,
    totalAmount: totalAmount ?? this.totalAmount,
    invoiceNum: invoiceNum ?? this.invoiceNum,
    externalInvoiceId: externalInvoiceId ?? this.externalInvoiceId,
    dueDate: dueDate ?? this.dueDate,
    sent: sent ?? this.sent,
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
    final filteredLines = _suppressOffsettingLines(chargeableLines);

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

  List<InvoiceLine> _suppressOffsettingLines(Iterable<InvoiceLine> lines) {
    final positives = <String, List<InvoiceLine>>{};
    final negatives = <String, List<InvoiceLine>>{};
    final kept = <InvoiceLine>[];

    for (final line in lines) {
      if (line.lineTotal.isZero) {
        continue;
      }

      final key = _offsetKey(line);
      final isNegative = line.lineTotal.isNegative;
      final oppositeMap = isNegative ? positives : negatives;
      final sameMap = isNegative ? negatives : positives;
      final opposite = oppositeMap[key];
      if (opposite != null && opposite.isNotEmpty) {
        opposite.removeLast();
        continue;
      }
      sameMap.putIfAbsent(key, () => []).add(line);
      kept.add(line);
    }

    return kept.where((line) {
      final key = _offsetKey(line);
      final isNegative = line.lineTotal.isNegative;
      final map = isNegative ? negatives : positives;
      final bucket = map[key];
      if (bucket == null || bucket.isEmpty) {
        return false;
      }
      final index = bucket.indexWhere((candidate) => candidate.id == line.id);
      if (index == -1) {
        return false;
      }
      bucket.removeAt(index);
      return true;
    }).toList();
  }

  String _offsetKey(InvoiceLine line) {
    final absLineTotal = line.lineTotal.isNegative
        ? (-line.lineTotal).minorUnits.toInt()
        : line.lineTotal.minorUnits.toInt();
    final absQty = line.quantity.compareTo(Fixed.zero) < 0
        ? (-line.quantity).minorUnits.toInt()
        : line.quantity.minorUnits.toInt();
    final description = line.description
        .replaceFirst(
          RegExp(r'^(material:|returned:|tool hire:)\s*', caseSensitive: false),
          '',
        )
        .trim()
        .toLowerCase();
    return '$description|$absLineTotal|$absQty';
  }

  XeroLineItem _toXeroLineItem(
    InvoiceLine line, {
    required String accountCode,
    required String itemCode,
  }) {
    var quantity = line.quantity;
    if (quantity.compareTo(Fixed.zero) < 0) {
      quantity = -quantity;
    }

    var unitAmount = line.unitPrice;
    if (line.lineTotal.isNegative) {
      if (!unitAmount.isNegative) {
        unitAmount = -unitAmount;
      }
    } else if (unitAmount.isNegative) {
      unitAmount = -unitAmount;
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
    'billing_contact_id': billingContactId,
  };
}

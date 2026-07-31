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

import 'dart:io';

import 'package:money2/money2.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../dao/dao.g.dart';
import '../../../../entity/entity.g.dart';
import '../../../../util/dart/format.dart';
import '../../../invoicing/pdf/generate_invoice_pdf.dart';

Future<File> buildDebtorStatementPdfFile({
  required String fileName,
  required DebtorStatementReport report,
}) async {
  final system = await DaoSystem().get();
  final phone = await formatPhone(system.bestPhone);
  final logo = await _getLogo(system);
  final rows = _statementRows(report);
  final systemColor = PdfColor.fromInt(system.billingColour);
  final generatedAt = _formatTimestamp(DateTime.now());

  final pdf = pw.Document()
    ..addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: pw.EdgeInsets.zero,
          buildBackground: (context) =>
              _background(context, system, systemColor, generatedAt),
        ),
        build: (context) => [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(22, 48, 22, 48),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _header(system, phone, logo, report),
                pw.SizedBox(height: 34),
                _statementTable(rows, systemColor),
                pw.SizedBox(height: 12),
                _balanceDue(report.closingBalance),
                pw.SizedBox(height: 16),
                _howToPay(system),
              ],
            ),
          ),
        ],
      ),
    );

  final dir = await Directory.systemTemp.createTemp('hmb_statement_pdf_');
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(await pdf.save(), flush: true);
  return file;
}

pw.Widget _background(
  pw.Context context,
  SystemConfiguration system,
  PdfColor systemColor,
  String generatedAt,
) => pw.Stack(
  children: [
    pw.Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: pw.Container(
        height: 28,
        color: systemColor,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8),
        alignment: pw.Alignment.centerLeft,
        child: pw.Text(
          system.businessName ?? '',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ),
    ),
    pw.Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: pw.Container(
        height: 28,
        color: systemColor,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated $generatedAt',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
            ),
            pw.Text(
              '${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
            ),
          ],
        ),
      ),
    ),
  ],
);

pw.Widget _header(
  SystemConfiguration system,
  String phone,
  pw.Widget? logo,
  DebtorStatementReport report,
) => pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Expanded(
      flex: 5,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'STATEMENT - Activity',
            style: const pw.TextStyle(fontSize: 24),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            report.customerName,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    ),
    pw.Expanded(
      flex: 2,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _labelValue('From Date', formatDate(report.startInclusive)),
          _labelValue('To Date', formatDate(_lastDay(report))),
          pw.SizedBox(height: 8),
          if (system.businessNumberLabel != null &&
              system.businessNumber != null &&
              system.businessNumber!.isNotEmpty)
            _labelValue(system.businessNumberLabel!, system.businessNumber!),
        ],
      ),
    ),
    pw.Expanded(
      flex: 3,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (logo != null) logo,
          pw.SizedBox(height: 8),
          pw.Text(
            system.businessName ?? '',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          if (system.address.isNotEmpty)
            pw.Text(system.address, textAlign: pw.TextAlign.right),
          if (phone.isNotEmpty) pw.Text(phone, textAlign: pw.TextAlign.right),
          if (system.emailAddress != null && system.emailAddress!.isNotEmpty)
            pw.Text(system.emailAddress!, textAlign: pw.TextAlign.right),
        ],
      ),
    ),
  ],
);

pw.Widget _labelValue(String label, String value) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    pw.Text(value),
  ],
);

pw.Widget _statementTable(List<_StatementPdfRow> rows, PdfColor systemColor) =>
    pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(62),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1.3),
        3: pw.FixedColumnWidth(78),
        4: pw.FixedColumnWidth(86),
        5: pw.FixedColumnWidth(72),
      },
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
        bottom: pw.BorderSide(width: 0.8),
      ),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: systemColor),
          children: [
            _headerCell('Date'),
            _headerCell('Activity'),
            _headerCell('Reference'),
            _headerCell('Invoice Amount', alignRight: true),
            _headerCell('Payments/\nCredits', alignRight: true),
            _headerCell('Balance', alignRight: true),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              _tableCell(_formatRowDate(row)),
              _tableCell(
                row.activity,
                style: pw.TextStyle(
                  fontSize: 9,
                  color: _statementActivityColor(row),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              _tableCell(row.reference),
              _tableCell(row.invoiceAmount?.toString() ?? '', alignRight: true),
              _tableCell(row.paymentAmount?.toString() ?? '', alignRight: true),
              _tableCell(row.balance.toString(), alignRight: true),
            ],
          ),
      ],
    );

pw.Widget _headerCell(String text, {bool alignRight = false}) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
  alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
  child: pw.Text(
    text,
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
  ),
);

pw.Widget _tableCell(
  String text, {
  bool alignRight = false,
  pw.TextStyle style = const pw.TextStyle(fontSize: 9),
}) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
  alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
  child: pw.Text(text, style: style),
);

PdfColor _statementActivityColor(_StatementPdfRow row) => switch (row.type) {
  DebtorStatementEntryType.invoice => PdfColors.blue700,
  DebtorStatementEntryType.payment ||
  DebtorStatementEntryType.credit => PdfColors.green700,
  DebtorStatementEntryType.adjustment => PdfColors.orange800,
  null => PdfColors.black,
};

String _formatRowDate(_StatementPdfRow row) {
  final date = row.date;
  if (date == null) {
    return '';
  }
  return formatDate(date);
}

pw.Widget _balanceDue(Money balance) => pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.end,
  children: [
    pw.Text(
      'BALANCE DUE',
      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(width: 12),
    pw.Text(
      balance.toString(),
      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
    ),
  ],
);

pw.Widget _howToPay(SystemConfiguration system) {
  final rows = <pw.Widget>[];
  if (system.paymentOptions.trim().isNotEmpty) {
    rows.add(pw.Text('Payment Options: ${system.paymentOptions}'));
  }
  if (system.showBsbAccountOnInvoice ?? false) {
    if (system.bsb != null && system.bsb!.trim().isNotEmpty) {
      rows.add(pw.Text('BSB: ${system.bsb}'));
    }
    if (system.accountNo != null && system.accountNo!.trim().isNotEmpty) {
      rows.add(pw.Text('Account Number: ${system.accountNo}'));
    }
  }
  if ((system.showPaymentLinkOnInvoice ?? false) &&
      system.paymentLinkUrl != null &&
      system.paymentLinkUrl!.trim().isNotEmpty) {
    rows.add(
      pw.UrlLink(
        destination: system.paymentLinkUrl!,
        child: pw.Text(
          'Pay online',
          style: const pw.TextStyle(
            color: PdfColors.blue,
            decoration: pw.TextDecoration.underline,
          ),
        ),
      ),
    );
  }
  rows.add(pw.Text(paymentTerms(system)));
  if (system.termsUrl != null && system.termsUrl!.trim().isNotEmpty) {
    rows.add(
      pw.UrlLink(
        destination: system.termsUrl!,
        child: pw.Text(
          'Terms and Conditions',
          style: const pw.TextStyle(
            color: PdfColors.blue,
            decoration: pw.TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'How to pay',
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      ...rows,
    ],
  );
}

List<_StatementPdfRow> _statementRows(DebtorStatementReport report) {
  var balance = report.openingBalance;
  final rows = <_StatementPdfRow>[
    _StatementPdfRow(
      type: null,
      date: report.startInclusive,
      activity: 'Opening balance',
      reference: '',
      invoiceAmount: null,
      paymentAmount: null,
      balance: balance,
    ),
  ];
  for (final entry in report.entries) {
    balance += entry.amount;
    rows.add(_StatementPdfRow.entry(entry, balance));
  }
  rows.add(
    _StatementPdfRow(
      type: null,
      date: _lastDay(report),
      activity: 'Closing balance',
      reference: '',
      invoiceAmount: null,
      paymentAmount: null,
      balance: balance,
    ),
  );
  return rows;
}

DateTime _lastDay(DebtorStatementReport report) =>
    report.endExclusive.subtract(const Duration(days: 1));

Future<pw.Widget?> _getLogo(SystemConfiguration system) async {
  final logoPath = system.logoPath;
  if (logoPath.isEmpty) {
    return null;
  }
  final file = File(logoPath);
  if (!file.existsSync()) {
    return null;
  }
  return pw.Image(
    pw.MemoryImage(await file.readAsBytes()),
    width: system.logoAspectRatio.width.toDouble(),
    height: system.logoAspectRatio.height.toDouble(),
  );
}

String _formatTimestamp(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

class _StatementPdfRow {
  final DebtorStatementEntryType? type;
  final DateTime? date;
  final String activity;
  final String reference;
  final Money? invoiceAmount;
  final Money? paymentAmount;
  final Money balance;

  const _StatementPdfRow({
    required this.type,
    required this.date,
    required this.activity,
    required this.reference,
    required this.invoiceAmount,
    required this.paymentAmount,
    required this.balance,
  });

  factory _StatementPdfRow.entry(DebtorStatementEntry entry, Money balance) =>
      _StatementPdfRow(
        type: entry.type,
        date: entry.date,
        activity: entry.description,
        reference: entry.invoiceNumber,
        invoiceAmount: entry.amount.isNegative ? null : entry.amount,
        paymentAmount: entry.amount.isNegative ? -entry.amount : null,
        balance: balance,
      );
}

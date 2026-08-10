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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../dao/dao_system.dart';
import '../../../dialog/email_dialog.dart';
import '../../../widgets/hmb_toast.dart';
import '../../../widgets/media/pdf_preview.dart';

String accountingReportExportFileName({
  required String reportName,
  required String extension,
  DateTime? startInclusive,
  DateTime? endInclusive,
  DateTime? asAt,
  String? entityName,
  int? entityId,
}) {
  final parts = <String>[
    _slug(reportName),
    if (entityName != null && entityName.trim().isNotEmpty) _slug(entityName),
    if (entityId != null) entityId.toString(),
    if (startInclusive != null && endInclusive != null)
      '${_dateStamp(startInclusive)}_to_${_dateStamp(endInclusive)}'
    else if (asAt != null)
      'as_at_${_dateStamp(asAt)}',
  ].where((part) => part.isNotEmpty).toList();

  final safeExtension = extension.startsWith('.')
      ? extension.substring(1)
      : extension;
  return '${parts.join('_')}.$safeExtension';
}

Future<void> exportCsv({required String fileName, required String csv}) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Export CSV',
    fileName: fileName,
    bytes: Uint8List.fromList(utf8.encode(csv)),
  );
  if (path == null) {
    return;
  }
  HMBToast.info('CSV exported to $path');
}

Future<void> exportReportPdf({
  required String fileName,
  required String title,
  required List<List<String>> rows,
}) async {
  final bytes = await buildReportPdfBytes(title: title, rows: rows);

  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Export PDF',
    fileName: fileName,
    bytes: bytes,
  );
  if (path == null) {
    return;
  }
  HMBToast.info('PDF exported to $path');
}

Future<void> sendReportCsv({
  required BuildContext context,
  required String fileName,
  required String title,
  required String csv,
  String preferredRecipient = '',
  List<String> emailRecipients = const [],
  String? emailBody,
}) async {
  final file = await buildReportCsvFile(fileName: fileName, csv: csv);
  if (!context.mounted) {
    return;
  }
  await showDialog<bool>(
    context: context,
    builder: (context) => EmailDialog(
      preferredRecipient: preferredRecipient,
      subject: title,
      body: emailBody ?? 'Please find attached the $title CSV report.',
      attachmentPaths: [file.path],
      emailRecipients: [...emailRecipients],
    ),
  );
}

Future<void> viewSendReportPdf({
  required BuildContext context,
  required String fileName,
  required String title,
  required List<List<String>> rows,
}) async {
  final file = await buildReportPdfFile(
    fileName: fileName,
    title: title,
    rows: rows,
  );
  if (!context.mounted) {
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => PdfPreviewScreen(
        title: title,
        filePath: file.path,
        preferredRecipient: '',
        emailSubject: title,
        emailBody: 'Please find attached the $title PDF report.',
        sendEmailDialog:
            ({
              required preferredRecipient,
              required subject,
              required body,
              required attachmentPaths,
            }) => EmailDialog(
              preferredRecipient: preferredRecipient,
              subject: subject,
              body: body,
              attachmentPaths: attachmentPaths,
              emailRecipients: const <String>[],
            ),
        canEmail: () async => EmailBlocked(blocked: false, reason: ''),
        onSent: () async {},
      ),
    ),
  );
}

Future<Uint8List> buildReportPdfBytes({
  required String title,
  required List<List<String>> rows,
}) async {
  final system = await DaoSystem().get();
  final systemColor = PdfColor.fromInt(system.billingColour);
  final businessName = system.businessName?.trim() ?? '';
  final generatedAt = _formatTimestamp(DateTime.now());

  final pdf = pw.Document()
    ..addPage(
      pw.MultiPage(
        pageTheme: _reportPageTheme(
          systemColor: systemColor,
          businessName: businessName,
          generatedAt: generatedAt,
        ),
        build: (_) => [
          _reportHeader(title: title, businessName: businessName),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(20, 0, 20, 44),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (rows.isEmpty)
                  pw.Text('No report data.')
                else
                  pw.TableHelper.fromTextArray(
                    data: rows,
                    headerStyle: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    headerDecoration: pw.BoxDecoration(color: systemColor),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    cellPadding: const pw.EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 4,
                    ),
                    oddRowDecoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    border: pw.TableBorder.all(
                      color: PdfColors.grey400,
                      width: 0.4,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  return Uint8List.fromList(await pdf.save());
}

class DebtorStatementPdfRow {
  final String date;
  final String invoiceNumber;
  final String description;
  final String amount;

  const DebtorStatementPdfRow({
    required this.date,
    required this.invoiceNumber,
    required this.description,
    required this.amount,
  });
}

Future<Uint8List> buildDebtorStatementPdfBytes({
  required String title,
  required String customerName,
  required String period,
  required String openingBalance,
  required String closingBalance,
  required List<DebtorStatementPdfRow> rows,
}) async {
  final system = await DaoSystem().get();
  final systemColor = PdfColor.fromInt(system.billingColour);
  final businessName = system.businessName?.trim() ?? '';
  final generatedAt = _formatTimestamp(DateTime.now());

  final pdf = pw.Document()
    ..addPage(
      pw.MultiPage(
        pageTheme: _reportPageTheme(
          systemColor: systemColor,
          businessName: businessName,
          generatedAt: generatedAt,
        ),
        build: (_) => [
          _reportHeader(title: title, businessName: businessName),
          _statementSummaryTable(
            systemColor: systemColor,
            customerName: customerName,
            period: period,
            openingBalance: openingBalance,
            closingBalance: closingBalance,
          ),
          pw.SizedBox(height: 10),
          if (rows.isEmpty)
            pw.Text('No statement activity for this period.')
          else
            _statementActivityTable(systemColor: systemColor, rows: rows),
        ],
      ),
    );

  return Uint8List.fromList(await pdf.save());
}

Future<File> buildDebtorStatementPdfFile({
  required String fileName,
  required String title,
  required String customerName,
  required String period,
  required String openingBalance,
  required String closingBalance,
  required List<DebtorStatementPdfRow> rows,
}) async {
  final dir = await Directory.systemTemp.createTemp('hmb_report_pdf_');
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(
    await buildDebtorStatementPdfBytes(
      title: title,
      customerName: customerName,
      period: period,
      openingBalance: openingBalance,
      closingBalance: closingBalance,
      rows: rows,
    ),
    flush: true,
  );
  return file;
}

pw.Widget _reportHeader({
  required String title,
  required String businessName,
}) => pw.Padding(
  padding: const pw.EdgeInsets.fromLTRB(20, 44, 20, 12),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        businessName,
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
      ),
    ],
  ),
);

pw.PageTheme _reportPageTheme({
  required PdfColor systemColor,
  required String businessName,
  required String generatedAt,
}) => pw.PageTheme(
  margin: pw.EdgeInsets.zero,
  buildBackground: (context) => pw.Stack(
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
            businessName,
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
  ),
);

pw.Widget _statementSummaryTable({
  required PdfColor systemColor,
  required String customerName,
  required String period,
  required String openingBalance,
  required String closingBalance,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 20),
  child: pw.Column(
    children: [
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        columnWidths: const {
          0: pw.FixedColumnWidth(70),
          1: pw.FlexColumnWidth(),
        },
        children: [
          pw.TableRow(
            children: [
              _statementCell('Customer', systemColor: systemColor),
              _statementCell(customerName),
            ],
          ),
          pw.TableRow(
            children: [
              _statementCell('Period', systemColor: systemColor),
              _statementCell(period),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        columnWidths: const {
          0: pw.FlexColumnWidth(),
          1: pw.FixedColumnWidth(95),
        },
        children: [
          pw.TableRow(
            children: [
              _statementCell('Opening balance'),
              _statementAmountCell(openingBalance),
            ],
          ),
          pw.TableRow(
            children: [
              _statementCell('Closing balance'),
              _statementAmountCell(closingBalance),
            ],
          ),
        ],
      ),
    ],
  ),
);

pw.Widget _statementActivityTable({
  required PdfColor systemColor,
  required List<DebtorStatementPdfRow> rows,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 20),
  child: pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
    columnWidths: const {
      0: pw.FixedColumnWidth(58),
      1: pw.FixedColumnWidth(72),
      2: pw.FlexColumnWidth(),
      3: pw.FixedColumnWidth(82),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: systemColor),
        children: [
          _statementCell('Date', header: true),
          _statementCell('Invoice', header: true),
          _statementCell('Description', header: true),
          _statementCell('Amount', header: true, rightAlign: true),
        ],
      ),
      for (var i = 0; i < rows.length; i++)
        pw.TableRow(
          decoration: i.isOdd
              ? const pw.BoxDecoration(color: PdfColors.grey100)
              : null,
          children: [
            _statementCell(rows[i].date),
            _statementCell(rows[i].invoiceNumber),
            _statementCell(rows[i].description),
            _statementAmountCell(rows[i].amount),
          ],
        ),
    ],
  ),
);

pw.Widget _statementCell(
  String value, {
  PdfColor? systemColor,
  bool header = false,
  bool rightAlign = false,
}) => pw.Container(
  color: systemColor,
  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
  alignment: rightAlign ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
  child: pw.Text(
    value,
    textAlign: rightAlign ? pw.TextAlign.right : pw.TextAlign.left,
    style: pw.TextStyle(
      fontSize: 9,
      color: header || systemColor != null ? PdfColors.white : PdfColors.black,
      fontWeight: header || systemColor != null
          ? pw.FontWeight.bold
          : pw.FontWeight.normal,
    ),
  ),
);

pw.Widget _statementAmountCell(String value) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
  alignment: pw.Alignment.centerRight,
  child: pw.Text(
    value,
    textAlign: pw.TextAlign.right,
    softWrap: false,
    maxLines: 1,
    overflow: pw.TextOverflow.clip,
    style: const pw.TextStyle(fontSize: 9),
  ),
);

Future<File> buildReportCsvFile({
  required String fileName,
  required String csv,
}) async {
  final dir = await Directory.systemTemp.createTemp('hmb_report_csv_');
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(csv, flush: true);
  return file;
}

Future<File> buildReportPdfFile({
  required String fileName,
  required String title,
  required List<List<String>> rows,
}) async {
  final dir = await Directory.systemTemp.createTemp('hmb_report_pdf_');
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(
    await buildReportPdfBytes(title: title, rows: rows),
    flush: true,
  );
  return file;
}

String _slug(String value) {
  final lower = value.trim().toLowerCase();
  final normalised = lower.replaceAll(RegExp('[^a-z0-9]+'), '_');
  return normalised.replaceAll(RegExp(r'^_+|_+$'), '');
}

String _dateStamp(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatTimestamp(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

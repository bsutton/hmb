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
import 'package:pdf/widgets.dart' as pw;

import '../../../widgets/hmb_toast.dart';

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

Future<Uint8List> buildReportPdfBytes({
  required String title,
  required List<List<String>> rows,
}) async {
  final pdf = pw.Document()
    ..addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text(title, style: const pw.TextStyle(fontSize: 18)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(data: rows),
        ],
      ),
    );
  return Uint8List.fromList(await pdf.save());
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

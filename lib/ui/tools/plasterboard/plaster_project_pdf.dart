/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../entity/entity.g.dart';
import '../../../util/dart/plaster_geometry.dart';

Future<File> generatePlasterProjectPdf({
  required PlasterProject project,
  required Job? job,
  required Task? task,
  required Supplier? supplier,
  required List<PlasterRoomShape> roomShapes,
  required List<PlasterSurfaceLayout> layouts,
}) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(24)),
      build: (_) => [
        pw.Text(
          project.name,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (job != null) pw.Text('Job: ${job.summary}'),
        if (task != null) pw.Text('Task: ${task.name}'),
        if (supplier != null) pw.Text('Supplier: ${supplier.name}'),
        pw.Text('Waste: ${project.wastePercent}%'),
        pw.SizedBox(height: 16),
        for (final shape in roomShapes) ...[
          pw.Text(
            shape.room.name,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.SvgImage(svg: buildRoomSvg(shape), height: 220),
          pw.SizedBox(height: 12),
        ],
        pw.Text(
          'Sheet Layout',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ['Surface', 'Sheet', 'Grid', 'Sheets', 'Sheets+waste'],
          data: [
            for (final layout in layouts)
              [
                layout.label,
                layout.material.name,
                '${layout.sheetsAcross} x ${layout.sheetsDown}',
                '${layout.sheetCount}',
                '${layout.sheetCountWithWaste}',
              ],
          ],
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
        ),
      ],
    ),
  );

  final output = await Directory.systemTemp.createTemp('plaster_project_');
  final file = File('${output.path}/plaster_project_${project.id}.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}

String buildRoomSvg(PlasterRoomShape shape) {
  if (shape.lines.isEmpty) {
    return '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="220"></svg>';
  }
  final xs = shape.lines.map((line) => line.startX).toList()..sort();
  final ys = shape.lines.map((line) => line.startY).toList()..sort();
  final minX = xs.first.toDouble();
  final minY = ys.first.toDouble();
  final maxX = xs.last.toDouble();
  final maxY = ys.last.toDouble();
  final width = (maxX - minX).abs();
  final height = (maxY - minY).abs();
  final scale = width == 0 || height == 0
      ? 1.0
      : (360 / width).clamp(0.2, 20.0).clamp(0.2, 20.0);
  final points = [
    for (final line in shape.lines)
      [
        (20 + ((line.startX - minX) * scale)).toStringAsFixed(1),
        (20 + ((line.startY - minY) * scale)).toStringAsFixed(1),
      ].join(','),
  ].join(' ');
  final labels = <String>[];
  for (var i = 0; i < shape.lines.length; i++) {
    final line = shape.lines[i];
    final end = PlasterGeometry.lineEnd(shape.lines, i);
    final midX = 20 + (((line.startX + end.x) / 2 - minX) * scale);
    final midY = 20 + (((line.startY + end.y) / 2 - minY) * scale);
    labels.add(
      '<text x="${midX.toStringAsFixed(1)}" y="${midY.toStringAsFixed(1)}" '
      'font-size="10" fill="#1f2937">W${i + 1}</text>',
    );
  }
  return '''
<svg xmlns="http://www.w3.org/2000/svg" width="400" height="240" viewBox="0 0 400 240">
  <rect x="0" y="0" width="400" height="240" fill="#ffffff" />
  <polygon points="$points" fill="#eff6ff" stroke="#1d4ed8" stroke-width="2" />
  ${labels.join('\n')}
</svg>
''';
}

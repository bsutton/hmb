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

/// lib/src/services/assignment_pdf_generator.dart
library;

import 'dart:io';
import 'dart:math';

import 'package:dcli_core/dcli_core.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../cache/hmb_image_cache.dart';
import '../../../cache/image_cache_config.dart';
import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/flutter/flutter_util.g.dart';

/// Internal data holder for task plus its resolved photos
class _TaskData {
  final Task task;
  final List<PhotoMeta> photos;
  final List<TaskItem> taskItems;

  _TaskData({
    required this.task,
    required this.photos,
    required this.taskItems,
  });
}

/// Generates a PDF for a Task Approval,
/// including task photos under each task.
Future<File> generateWorkAssignmentPdf(WorkAssignment assignment) async {
  final pdf = pw.Document();
  final system = await DaoSystem().get();
  final useMetric = system.preferredUnitSystem == PreferredUnitSystem.metric;
  final systemColor = PdfColor.fromInt(system.billingColour);
  final satDao = DaoWorkAssignmentTask();
  final supplierDao = DaoSupplier();
  final taskDao = DaoTask();

  Units resolveUnits(MeasurementType type) =>
      useMetric ? type.defaultMetric : type.defaultImperial;

  final supplier = await supplierDao.getById(assignment.supplierId);
  final contact = await DaoContact().getById(assignment.contactId);
  final job = await DaoJob().getById(assignment.jobId);
  final site = job?.siteId != null
      ? await DaoSite().getById(job!.siteId)
      : null;
  final customer = job?.customerId != null
      ? await DaoCustomer().getById(job!.customerId)
      : null;
  final primaryContact = await DaoContact().getPrimaryForJob(job?.id);

  // Prefetch tasks plus their photo metadata
  final joins = await satDao.getByAssignment(assignment.id);
  final taskDataList = <_TaskData>[];
  for (final join in joins) {
    final task = await taskDao.getById(join.taskId);
    if (task == null) {
      continue;
    }
    final photos = await DaoPhoto.getByTask(task.id);
    final metas = await PhotoMeta.resolveAll(photos);
    final taskItems = await DaoTaskItem().getByTask(task.id);
    taskDataList.add(
      _TaskData(task: task, photos: metas, taskItems: taskItems),
    );
  }

  // --- Limit concurrent isolates for image compression
  // leaving 1 cpu so the UI will continue updating ---
  final maxConcurrent = max(1, Platform.numberOfProcessors - 1);
  final compressedBytes = <Path, Uint8List>{};
  final allMetas = taskDataList
      .expand((d) => d.photos)
      .where((m) => exists(m.absolutePathTo))
      .toList();

  for (var i = 0; i < allMetas.length; i += maxConcurrent) {
    final batch = allMetas.skip(i).take(maxConcurrent).toList();
    final futures = batch
        .map(
          (meta) => HMBImageCache().getVariantBytesForMeta(
            meta: meta,
            variant: ImageVariantType.pdf,
          ),
        )
        .toList();
    final results = await Future.wait(futures);
    for (var j = 0; j < batch.length; j++) {
      final bytes = results[j];
      if (bytes.isNotEmpty) {
        compressedBytes[batch[j].absolutePathTo] = bytes;
      }
    }
  }

  pdf.addPage(
    pw.MultiPage(
      pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(24)),
      // Header: top band with title on every page, plus page1 details below
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Top band with title
          pw.Container(
            height: 28,
            color: systemColor,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10),
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              'Task Approval',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          // Only on page 1: details block
          if (context.pageNumber == 1)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8, bottom: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (supplier != null) pw.Text('Supplier: ${supplier.name}'),
                  if (contact != null) ...[
                    pw.Text('Contact: ${contact.fullname}'),
                    pw.Text('Email: ${contact.emailAddress}'),
                    pw.Text('Phone: ${contact.bestPhone}'),
                  ],
                  if (customer != null) pw.Text('Customer: ${customer.name}'),
                  if (site != null) pw.Text('Address: ${site.address}'),
                  if (primaryContact != null)
                    pw.Text('Phone: ${primaryContact.bestPhone}'),
                  if (job != null) pw.Text('Job: ${job.summary}'),
                  pw.Divider(thickness: 1.5),
                ],
              ),
            ),
        ],
      ),
      // Footer with bottom band and page number
      footer: (context) => pw.Container(
        height: 28,
        color: systemColor,
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
            ),
          ),
        ),
      ),
      // Main content: only task details here
      build: (context) {
        final content = <pw.Widget>[];
        for (final data in taskDataList) {
          content.addAll([
            pw.Text(
              'Task: ${data.task.name}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
          ]);
          // Description & Assumptions
          if (data.task.description.isNotEmpty) {
            content.add(pw.Text('Description: ${data.task.description}'));
          }
          if (data.task.assumption.isNotEmpty) {
            content.add(pw.Text('Assumptions: ${data.task.assumption}'));
          }

          final materials = data.taskItems.where((item) {
            final type = item.itemType;
            return type == TaskItemType.materialsBuy ||
                type == TaskItemType.materialsStock ||
                type == TaskItemType.consumablesStock ||
                type == TaskItemType.consumablesBuy;
          }).toList();

          if (materials.isNotEmpty) {
            content
              ..add(pw.SizedBox(height: 6))
              ..add(
                pw.Text(
                  'Materials:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              );

            for (final item in materials) {
              final units =
                  item.units ??
                  resolveUnits(item.measurementType ?? MeasurementType.length);
              final dimensionsStr = item.hasDimensions
                  ? units.format([
                      item.dimension1,
                      item.dimension2,
                      item.dimension3,
                    ])
                  : '';
              final quantity = item.estimatedMaterialQuantity?.toString() ?? '';
              final cost = item.estimatedMaterialUnitCost?.toString() ?? '';

              content.add(
                pw.Bullet(
                  text:
                      '${item.description} '
                      '''${dimensionsStr.isNotEmpty ? "($dimensionsStr ${units.name}) " : ""}'''
                      'Qty: $quantity '
                      '${cost.isNotEmpty ? "Cost/unit: $cost" : ""}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              );

              if (item.purpose.isNotEmpty) {
                content.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 20, bottom: 4),
                    child: pw.Text(
                      item.purpose,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),
                );
                // Display URL if present
                if (item.url.isNotEmpty) {
                  content.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 20, bottom: 4),
                      child: pw.UrlLink(
                        destination: item.url,
                        child: pw.Text(
                          item.url,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            decoration: pw.TextDecoration.underline,
                            color: PdfColors.blue,
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }
            }
          }

          // Photos (already compressed)
          if (data.photos.isNotEmpty) {
            content.add(pw.SizedBox(height: 8));
            for (final meta in data.photos) {
              final bytes = compressedBytes[meta.absolutePathTo];
              if (bytes == null) {
                continue;
              }
              content.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Image(pw.MemoryImage(bytes)),
                ),
              );
            }
          }

          content.addAll([
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.SizedBox(height: 12),
          ]);
        }
        return content;
      },
    ),
  );

  // --- Write out the PDF ---
  final dir = await getTemporaryDirectory();
  final out = File('$dir/assignment_${assignment.id}.pdf');
  await out.writeAsBytes(await pdf.save());
  return out;
}

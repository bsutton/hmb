/// Generates a PDF for a SupplierAssignment, including task photos under each task.
library;

import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:flutter/foundation.dart'; // for compute()
import 'package:image/image.dart' as img; // image decoding/resizing
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/util.g.dart';

/// Internal data holder for task plus its resolved photos
class _TaskData {
  _TaskData({required this.task, required this.photos});
  final Task task;
  final List<PhotoMeta> photos;
}

/// Top‐level function to run in an isolate: reads,
/// downsizes (max width 200px), JPEG‐encodes (70% quality)
/// and returns the compressed bytes.
Uint8List _compressImageTask(String absolutePath) {
  final raw = File(absolutePath).readAsBytesSync();
  final original = img.decodeImage(raw);
  if (original == null) {
    return Uint8List(0);
  }
  final resized = img.copyResize(original, width: 200);
  final jpeg = img.encodeJpg(resized, quality: 70);
  return Uint8List.fromList(jpeg);
}

/// Generates a PDF for a SupplierAssignment,
/// including pre‐compressed task photos.
Future<File> generateAssignmentPdf(SupplierAssignment assignment) async {
  final pdf = pw.Document();

  // --- Fetch your data from DAOs ---
  final satDao = DaoSupplierAssignmentTask();
  final supplierDao = DaoSupplier();
  final taskDao = DaoTask();

  final supplier = await supplierDao.getById(assignment.supplierId);
  final contact = await DaoContact().getById(assignment.contactId);

  final job = await DaoJob().getById(assignment.jobId);
  final site = (job?.siteId != null)
      ? await DaoSite().getById(job!.siteId)
      : null;

  final customer = (job?.customerId != null)
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
    taskDataList.add(_TaskData(task: task, photos: metas));
  }

  // --- Pre-compress all images in background isolates ---
  final compressedBytes = <String, Uint8List>{};
  for (final data in taskDataList) {
    for (final meta in data.photos) {
      try {
        if (exists(meta.absolutePathTo)) {
          final bytes = await compute(_compressImageTask, meta.absolutePathTo);
          if (bytes.isNotEmpty) {
            compressedBytes[meta.absolutePathTo] = bytes;
          }
        }
      } catch (_) {
        // ignore failures
      }
    }
  }

  // --- Build the PDF pages ---
  pdf.addPage(
    pw.MultiPage(
      pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(24)),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Work Assignment',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          if (supplier != null)
            pw.Text(
              'Supplier: ${supplier.name}',
              style: const pw.TextStyle(fontSize: 14),
            ),
          if (contact != null) ...[
            pw.Text(
              'Contact: ${contact.fullname}',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              'Email: ${contact.emailAddress}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.Text(
              'Phone: ${contact.bestPhone}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 12),
          ],

          /// Customer details
          if (customer != null) ...[
            pw.Text(
              'Customer: ${customer.name}',
              style: const pw.TextStyle(fontSize: 14),
            ),
            if (site != null)
              pw.Text(
                'Address: ${site.address}',
                style: const pw.TextStyle(fontSize: 12),
              ),
            if (primaryContact != null)
              pw.Text(
                'Phone: ${primaryContact.bestPhone}',
                style: const pw.TextStyle(fontSize: 12),
              ),
            pw.SizedBox(height: 12),
          ],
          pw.Divider(thickness: 1.5),
          if (job != null) ...[
            pw.Text(
              'Job: ${job.summary}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            if (site != null) ...[
              pw.Text(
                'Site: ${site.address}',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.Text(site.address, style: const pw.TextStyle(fontSize: 12)),
            ],
            pw.Divider(thickness: 1),
          ],
        ],
      ),
      build: (context) {
        final content = <pw.Widget>[];
        for (final data in taskDataList) {
          // Task header
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

          // Photos (already compressed)
          if (data.photos.isNotEmpty) {
            content.add(pw.SizedBox(height: 8));
            for (final meta in data.photos) {
              final bytes = compressedBytes[meta.absolutePathTo];
              if (bytes == null) {
                continue;
              }
              final image = pw.MemoryImage(bytes);
              content.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Image(image),
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

  // --- Write out the pdf  ---
  final dir = await getTemporaryDirectory();
  final out = File('${dir.path}/assignment_${assignment.id}.pdf');
  await out.writeAsBytes(await pdf.save());
  return out;
}

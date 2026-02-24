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
import 'dart:math';

import 'package:dcli_core/dcli_core.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../cache/hmb_image_cache.dart';
import '../../../cache/image_cache_config.dart';
import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/photo_meta.dart';

class _TaskData {
  final Task task;
  final List<PhotoMeta> photos;
  final TaskApprovalDecision decision;

  _TaskData({required this.task, required this.photos, required this.decision});
}

Future<File> generateTaskApprovalPdf(TaskApproval approval) async {
  final pdf = pw.Document();
  final system = await DaoSystem().get();
  final systemColor = PdfColor.fromInt(system.billingColour);
  final joinDao = DaoTaskApprovalTask();
  final taskDao = DaoTask();

  final contact = await DaoContact().getById(approval.contactId);
  final job = await DaoJob().getById(approval.jobId);
  final site = job?.siteId != null
      ? await DaoSite().getById(job!.siteId)
      : null;
  final customer = job?.customerId != null
      ? await DaoCustomer().getById(job!.customerId)
      : null;

  final joins = await joinDao.getByApproval(approval.id);
  final taskDataList = <_TaskData>[];
  for (final join in joins) {
    final task = await taskDao.getById(join.taskId);
    if (task == null) {
      continue;
    }
    final photos = await DaoPhoto.getByTask(task.id);
    final metas = await PhotoMeta.resolveAll(photos);
    taskDataList.add(
      _TaskData(task: task, photos: metas, decision: join.status),
    );
  }

  final maxConcurrent = max(1, Platform.numberOfProcessors - 1);
  final compressedBytes = <String, Uint8List>{};
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
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
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
          if (context.pageNumber == 1)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8, bottom: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (customer != null) pw.Text('Customer: ${customer.name}'),
                  if (contact != null) ...[
                    pw.Text('Contact: ${contact.fullname}'),
                    pw.Text('Email: ${contact.emailAddress}'),
                    pw.Text('Phone: ${contact.bestPhone}'),
                  ],
                  if (site != null) pw.Text('Address: ${site.address}'),
                  if (job != null) pw.Text('Job: ${job.summary}'),
                  pw.Text('Sent: ${DateTime.now()}'),
                  pw.Divider(thickness: 1.5),
                  pw.Text(
                    'Please mark each task as approved or rejected and '
                    'return this list.',
                  ),
                ],
              ),
            ),
        ],
      ),
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
      build: (context) {
        final content = <pw.Widget>[];
        for (final data in taskDataList) {
          content.addAll([
            pw.Text(
              'Task: ${data.task.name}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Decision: ${data.decision.name}'),
            pw.SizedBox(height: 4),
          ]);

          if (data.task.description.isNotEmpty) {
            content.add(pw.Text('Description: ${data.task.description}'));
          }
          if (data.task.assumption.isNotEmpty) {
            content.add(pw.Text('Assumptions: ${data.task.assumption}'));
          }

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

  final output = await Directory.systemTemp.createTemp('task_approval_pdf_');
  final file = File('${output.path}/task_approval_${approval.id}.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}

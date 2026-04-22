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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:strings/strings.dart';

import '../../../cache/hmb_image_cache.dart';
import '../../../cache/image_cache_config.dart';
import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/photo_meta.dart';
import '../../dialog/email_dialog_for_job.dart';
import '../../invoicing/select_job_dialog.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/media/pdf_preview.dart';
import '../../widgets/widgets.g.dart';

class _ReportTask {
  final Task task;
  final List<PhotoMeta> availablePhotos;
  final List<PhotoMeta> selectedPhotos;

  _ReportTask({
    required this.task,
    required this.availablePhotos,
    required this.selectedPhotos,
  });
}

class _ReportSelection {
  final List<_ReportTask> tasks;

  _ReportSelection(this.tasks);
}

class _TaskPhotoGroup {
  final Task task;
  final List<PhotoMeta> photos;

  _TaskPhotoGroup({required this.task, required this.photos});
}

Future<void> showJobCompletionReport({
  required BuildContext context,
  required Job job,
}) async {
  final tasks = await DaoTask().getTasksByJob(job.id);
  if (tasks.isEmpty) {
    HMBToast.error('This job has no tasks to include in a report.');
    return;
  }

  final groups = <_TaskPhotoGroup>[];
  for (final task in tasks) {
    final photos = await DaoPhoto.getByTask(task.id);
    final metas = await PhotoMeta.resolveAll(photos);
    groups.add(_TaskPhotoGroup(task: task, photos: metas));
  }

  if (!context.mounted) {
    return;
  }

  final selection = await showDialog<_ReportSelection>(
    context: context,
    builder: (_) => _JobCompletionReportDialog(job: job, groups: groups),
  );
  if (selection == null) {
    return;
  }
  if (selection.tasks.isEmpty) {
    HMBToast.error('Select at least one task for the report.');
    return;
  }

  final file = await BlockingUI().runAndWait(
    label: 'Generating Job Report',
    () => _generateJobCompletionReportPdf(job, selection),
  );

  final primaryContact = await DaoContact().getPrimaryForJob(job.id);
  final billingContact = await DaoContact().getBillingContactByJob(job);
  final preferredRecipient =
      billingContact?.emailAddress ??
      primaryContact?.emailAddress ??
      await DaoJob().getBestEmail(job) ??
      '';
  final site = job.siteId == null ? null : await DaoSite().getById(job.siteId);
  final system = await DaoSystem().get();

  if (!context.mounted) {
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PdfPreviewScreen(
        title: 'Job Report #${job.id} ${job.summary}',
        filePath: file.path,
        preferredRecipient: preferredRecipient,
        emailSubject: '${system.businessName ?? 'Your'} Job Report #${job.id}',
        emailBody:
            '''
${primaryContact?.firstName.trim() ?? ''},

Please find attached the completion report for your job.
${site != null && site.address.isNotEmpty ? '\nSite Address: ${site.address}' : ''}
''',
        sendEmailDialog:
            ({
              preferredRecipient = '',
              subject = '',
              body = '',
              attachmentPaths = const [],
            }) => EmailDialogForJob(
              job: job,
              preferredRecipient: preferredRecipient,
              subject: subject,
              body: body,
              attachmentPaths: attachmentPaths,
            ),
        onSent: () async {},
        canEmail: () async => EmailBlocked(blocked: false, reason: ''),
      ),
    ),
  );
}

Future<void> showJobCompletionReportForSelectedJob({
  required BuildContext context,
}) async {
  final job = await SelectJobDialog.show(
    context,
    title: 'Select Job for Report',
    initialShowAllJobs: true,
    initialShowJobsWithNoBillableItems: true,
    showBillableFilters: false,
  );
  if (job == null || !context.mounted) {
    return;
  }

  await showJobCompletionReport(context: context, job: job);
}

class _JobCompletionReportDialog extends StatefulWidget {
  final Job job;
  final List<_TaskPhotoGroup> groups;

  const _JobCompletionReportDialog({required this.job, required this.groups});

  @override
  State<_JobCompletionReportDialog> createState() =>
      _JobCompletionReportDialogState();
}

class _JobCompletionReportDialogState
    extends State<_JobCompletionReportDialog> {
  final _selectedTasks = <int, bool>{};
  final _selectedPhotosByTask = <int, Set<int>>{};
  var _selectAllTasks = true;

  @override
  void initState() {
    super.initState();
    for (final group in widget.groups) {
      _selectedTasks[group.task.id] = true;
      _selectedPhotosByTask[group.task.id] = {
        for (final meta in group.photos) meta.photo.id,
      };
    }
  }

  void _toggleAllTasks(bool? value) {
    setState(() {
      _selectAllTasks = value ?? false;
      for (final taskId in _selectedTasks.keys) {
        _selectedTasks[taskId] = _selectAllTasks;
      }
    });
  }

  void _toggleTask(int taskId, bool? value) {
    setState(() {
      _selectedTasks[taskId] = value ?? false;
      _selectAllTasks = _selectedTasks.values.every((selected) => selected);
    });
  }

  void _togglePhoto(int taskId, int photoId, bool? value) {
    setState(() {
      final selected = _selectedPhotosByTask.putIfAbsent(taskId, () => {});
      if (value ?? false) {
        selected.add(photoId);
      } else {
        selected.remove(photoId);
      }
    });
  }

  void _save() {
    final reportTasks = <_ReportTask>[];
    for (final group in widget.groups) {
      if (_selectedTasks[group.task.id] != true) {
        continue;
      }

      final selectedIds = _selectedPhotosByTask[group.task.id] ?? {};
      reportTasks.add(
        _ReportTask(
          task: group.task,
          availablePhotos: group.photos,
          selectedPhotos: group.photos
              .where((meta) => selectedIds.contains(meta.photo.id))
              .toList(),
        ),
      );
    }
    Navigator.of(context).pop(_ReportSelection(reportTasks));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Job Report: ${widget.job.summary}'),
    content: SizedBox(
      width: 900,
      height: 620,
      child: ListView(
        children: [
          CheckboxListTile(
            title: const Text('Select All Tasks'),
            value: _selectAllTasks,
            onChanged: _toggleAllTasks,
          ),
          for (final group in widget.groups) _buildTaskSection(group),
        ],
      ),
    ),
    actions: [
      HMBButton(
        label: 'Cancel',
        hint: "Don't create the report",
        onPressed: () => Navigator.of(context).pop(),
      ),
      HMBButton(
        label: 'Create Report',
        hint: 'Create a report for the selected tasks and photos',
        onPressed: _save,
      ),
    ],
  );

  Widget _buildTaskSection(_TaskPhotoGroup group) {
    final taskSelected = _selectedTasks[group.task.id] ?? false;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(group.task.name),
              subtitle: Strings.isBlank(group.task.description)
                  ? null
                  : Text(group.task.description),
              value: taskSelected,
              onChanged: (value) => _toggleTask(group.task.id, value),
            ),
            if (taskSelected)
              if (group.photos.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 8),
                  child: Text('No photos available'),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final meta in group.photos)
                      _PhotoChoice(
                        meta: meta,
                        selected:
                            _selectedPhotosByTask[group.task.id]?.contains(
                              meta.photo.id,
                            ) ??
                            false,
                        onChanged: (value) =>
                            _togglePhoto(group.task.id, meta.photo.id, value),
                      ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

class _PhotoChoice extends StatelessWidget {
  final PhotoMeta meta;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  const _PhotoChoice({
    required this.meta,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final path = meta.absolutePathTo;
    final exists = File(path).existsSync();
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exists)
            Image.file(File(path), width: 180, height: 100, fit: BoxFit.cover)
          else
            Container(
              width: 180,
              height: 100,
              color: Colors.grey,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image, color: Colors.white),
            ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: selected,
            title: const Text('Include'),
            onChanged: onChanged,
          ),
          if (Strings.isNotBlank(meta.comment))
            Text(meta.comment!, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

Future<File> _generateJobCompletionReportPdf(
  Job job,
  _ReportSelection selection,
) async {
  final pdf = pw.Document();
  final system = await DaoSystem().get();
  final systemColor = PdfColor.fromInt(system.billingColour);
  final customer = await DaoCustomer().getById(job.customerId);
  final primaryContact = await DaoContact().getPrimaryForJob(job.id);
  final site = job.siteId == null ? null : await DaoSite().getById(job.siteId);
  final businessNumberLabel = system.businessNumberLabel ?? 'Business Number';
  final compressedBytes = await _compressSelectedPhotos(selection);

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
              'Job Completion Report',
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
              child: _buildReportHeader(
                job: job,
                system: system,
                customer: customer,
                contact: primaryContact,
                site: site,
                businessNumberLabel: businessNumberLabel,
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
      build: (_) {
        final content = <pw.Widget>[
          pw.Text(
            'Task Details',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
        ];

        for (var i = 0; i < selection.tasks.length; i++) {
          content.addAll(
            _buildTaskReportSection(
              number: i + 1,
              reportTask: selection.tasks[i],
              compressedBytes: compressedBytes,
            ),
          );
        }
        return content;
      },
    ),
  );

  final output = await getTemporaryDirectory();
  final file = File('${output.path}/job_report_${job.id}.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}

pw.Widget _buildReportHeader({
  required Job job,
  required System system,
  required Customer? customer,
  required Contact? contact,
  required Site? site,
  required String businessNumberLabel,
}) => pw.Column(
  children: [
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
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
              pw.Text('Job #: ${job.id}'),
              if (job.summary.trim().isNotEmpty)
                pw.Text('Summary: ${job.summary}'),
              if (job.description.trim().isNotEmpty)
                pw.Text(
                  'Description: ${job.description.replaceAll('\n', ' ')}',
                ),
              pw.Text('Generated: ${DateTime.now()}'),
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if ((system.businessName ?? '').trim().isNotEmpty)
                pw.Text(
                  'Business: ${system.businessName}',
                  textAlign: pw.TextAlign.right,
                ),
              if ((system.businessNumber ?? '').trim().isNotEmpty)
                pw.Text(
                  '$businessNumberLabel: ${system.businessNumber}',
                  textAlign: pw.TextAlign.right,
                ),
              if ((system.addressLine1 ?? '').trim().isNotEmpty)
                pw.Text(
                  '${system.addressLine1}',
                  textAlign: pw.TextAlign.right,
                ),
              if ((system.addressLine2 ?? '').trim().isNotEmpty)
                pw.Text(
                  '${system.addressLine2}',
                  textAlign: pw.TextAlign.right,
                ),
              if ((system.suburb ?? '').trim().isNotEmpty ||
                  (system.state ?? '').trim().isNotEmpty ||
                  (system.postcode ?? '').trim().isNotEmpty)
                pw.Text(
                  '${system.suburb ?? ''} ${system.state ?? ''} '
                          '${system.postcode ?? ''}'
                      .trim(),
                  textAlign: pw.TextAlign.right,
                ),
              if ((system.mobileNumber ?? '').trim().isNotEmpty)
                pw.Text(
                  'Mobile: ${system.mobileNumber}',
                  textAlign: pw.TextAlign.right,
                ),
              if ((system.emailAddress ?? '').trim().isNotEmpty)
                pw.Text(
                  'Email: ${system.emailAddress}',
                  textAlign: pw.TextAlign.right,
                ),
            ],
          ),
        ),
      ],
    ),
    pw.Divider(thickness: 1.5),
  ],
);

List<pw.Widget> _buildTaskReportSection({
  required int number,
  required _ReportTask reportTask,
  required Map<String, Uint8List> compressedBytes,
}) {
  final task = reportTask.task;
  final widgets = <pw.Widget>[
    pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$number. ${task.name}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Status: ${task.status.name}'),
          if (task.description.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text('Description: ${task.description}'),
            ),
          if (task.assumption.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text('Assumptions: ${task.assumption}'),
            ),
        ],
      ),
    ),
  ];

  if (reportTask.availablePhotos.isEmpty) {
    widgets.add(pw.Text('No photos available'));
  } else if (reportTask.selectedPhotos.isEmpty) {
    widgets.add(pw.Text('No photos selected'));
  } else {
    var renderedPhoto = false;
    for (final meta in reportTask.selectedPhotos) {
      final bytes = compressedBytes[meta.absolutePathTo];
      if (bytes == null) {
        continue;
      }
      renderedPhoto = true;
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Image(pw.MemoryImage(bytes)),
        ),
      );
      final comment = meta.comment?.trim() ?? '';
      if (comment.isNotEmpty) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text('Comment: $comment'),
          ),
        );
      }
    }
    if (!renderedPhoto) {
      widgets.add(pw.Text('Selected photos are unavailable'));
    }
  }

  widgets.addAll([
    pw.SizedBox(height: 12),
    pw.Divider(),
    pw.SizedBox(height: 12),
  ]);
  return widgets;
}

Future<Map<String, Uint8List>> _compressSelectedPhotos(
  _ReportSelection selection,
) async {
  final maxConcurrent = max(1, Platform.numberOfProcessors - 1);
  final compressedBytes = <String, Uint8List>{};
  final metas = selection.tasks
      .expand((task) => task.selectedPhotos)
      .where((meta) => File(meta.absolutePathTo).existsSync())
      .toList();

  for (var i = 0; i < metas.length; i += maxConcurrent) {
    final batch = metas.skip(i).take(maxConcurrent).toList();
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
  return compressedBytes;
}

/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../../entity/mailing.dart';
import '../../../entity/mailing_recipient.dart';
import 'label_layout.dart';

Future<File> generateMailingLabelPdf({
  required Mailing mailing,
  required List<MailingRecipient> recipients,
  required LabelLayout layout,
  int skipLabels = 0,
}) async {
  final bytes = await buildMailingLabelPdfBytes(
    recipients: recipients,
    layout: layout,
    skipLabels: skipLabels,
  );
  final output = await Directory.systemTemp.createTemp('mailing_labels_');
  final file = File('${output.path}/mailing_${mailing.id}_labels.pdf');
  await file.writeAsBytes(bytes);
  return file;
}

Future<Uint8List> buildMailingLabelPdfBytes({
  required List<MailingRecipient> recipients,
  required LabelLayout layout,
  int skipLabels = 0,
}) {
  final pdf = pw.Document();
  final slots = <MailingRecipient?>[
    for (var i = 0; i < skipLabels; i++) null,
    ...recipients,
  ];

  for (var pageStart = 0; pageStart < slots.length;) {
    final pageSlots = slots
        .skip(pageStart)
        .take(layout.labelsPerPage)
        .toList(growable: false);
    pageStart += layout.labelsPerPage;

    pdf.addPage(
      pw.Page(
        pageFormat: layout.pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(
          children: [
            for (var index = 0; index < pageSlots.length; index++)
              if (pageSlots[index] != null)
                _label(
                  recipient: pageSlots[index]!,
                  left:
                      layout.marginLeft +
                      (index % layout.columns) * layout.columnPitch,
                  top:
                      layout.marginTop +
                      (index ~/ layout.columns) * layout.rowPitch,
                  width: layout.labelWidth,
                  height: layout.labelHeight,
                ),
          ],
        ),
      ),
    );
  }

  if (slots.isEmpty) {
    pdf.addPage(
      pw.Page(
        pageFormat: layout.pageFormat,
        build: (_) => pw.Center(child: pw.Text('No ready recipients')),
      ),
    );
  }

  return pdf.save();
}

pw.Widget _label({
  required MailingRecipient recipient,
  required double left,
  required double top,
  required double width,
  required double height,
}) => pw.Positioned(
  left: left,
  top: top,
  child: pw.Container(
    width: width,
    height: height,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(
          recipient.contactName,
          maxLines: 1,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(recipient.addressLine1, maxLines: 1),
        if (recipient.addressLine2.trim().isNotEmpty)
          pw.Text(recipient.addressLine2, maxLines: 1),
        pw.Text(
          [
            recipient.suburb,
            recipient.state,
            recipient.postcode,
          ].where((part) => part.trim().isNotEmpty).join(' '),
          maxLines: 1,
        ),
      ],
    ),
  ),
);

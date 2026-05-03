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

// lib/src/services/quote_pdf_generator.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:strings/strings.dart';

import '../../dao/dao_job.dart';
import '../../dao/dao_photo.dart';
import '../../dao/dao_quote_task_photo.dart';
import '../../dao/dao_site.dart';
import '../../dao/dao_system.dart';
import '../../entity/quote.dart';
import '../../entity/quote_line.dart';
import '../../entity/system.dart';
import '../../util/dart/format.dart';
import '../../util/dart/money_ex.dart';
import '../../util/dart/photo_meta.dart';
import '../../util/dart/tax_display_text.dart';
import 'quote_details.dart';

Future<File> generateQuotePdf(
  Quote quote, {
  required bool displayItems,
  required bool displayCosts,
  required bool displayGroupHeaders,
}) async {
  final pdf = pw.Document();
  final system = await DaoSystem().get();
  final job = await DaoJob().getById(quote.jobId);
  final site = job?.siteId == null
      ? null
      : await DaoSite().getById(job!.siteId);
  final jobQuote = await QuoteDetails.fromQuoteId(
    quote.id,
    excludeHidden: true,
  );
  final visibleGroups = jobQuote.groups
      .map(
        (group) => QuoteLineGroupWithLines(
          group: group.group,
          lines: group.lines.where(_isCustomerVisibleQuoteLine).toList(),
        ),
      )
      .where((group) => group.lines.isNotEmpty)
      .toList();
  final taxDisplayText = await buildPdfTaxDisplayText();
  final appendix = await _loadQuotePhotoAppendix(jobQuote);

  final totalAmount = visibleGroups.fold(
    MoneyEx.zero,
    (sum, group) => sum + group.total,
  );
  final phone = await formatPhone(system.bestPhone);
  final logo = await _getLogo(system);
  final systemColor = PdfColor.fromInt(system.billingColour);

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.fromLTRB(20, 20, 20, 50),
        buildBackground: (context) => pw.Stack(
          children: [
            // Top band
            pw.Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: pw.Container(height: 28, color: systemColor),
            ),
            // Bottom band with T&C
            pw.Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: pw.Container(
                height: 28,
                color: systemColor,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.RichText(
                        text: pw.TextSpan(
                          text: 'This quote is subject to our ',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                          ),
                          children: [
                            pw.WidgetSpan(
                              // nudge the UrlLink down to align with the text
                              baseline: -2,
                              child: pw.UrlLink(
                                destination: system.termsUrl ?? '',
                                child: pw.Text(
                                  'Terms and Conditions',
                                  style: const pw.TextStyle(
                                    fontSize: 10,
                                    color: PdfColors.blue,
                                    decoration: pw.TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            const pw.TextSpan(
                              text: ' and is valid for 30 days',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),

                      pw.Text(
                        '${context.pageNumber} of ${context.pagesCount}',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      header: (context) {
        if (context.pageNumber == 1) {
          return pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(0, 10, 0, 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Fixed Price Quote: ${quote.bestNumber}',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text('Date: ${formatDate(quote.createdDate)}'),
                        if (job != null) pw.Text('Job: #${job.id}'),
                        if (site != null && site.address.trim().isNotEmpty)
                          pw.Text('Site: ${site.address}'),
                      ],
                    ),
                    ?logo,
                  ],
                ),
                pw.Divider(),
                pw.Text(
                  'Business Details:',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Business Name: ${system.businessName}'),
                pw.Text('Address: ${system.address}'),
                pw.Text('Email: ${system.emailAddress}'),
                pw.Text('Phone: $phone'),
                pw.Text(
                  '${system.businessNumberLabel}: ${system.businessNumber}',
                ),
                if (taxDisplayText != null) pw.Text(taxDisplayText),

                // --- NEW: Summary & Description (first page only) ---
                if (Strings.isNotBlank(quote.summary)) ...[
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Summary:',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    quote.summary,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
                if (Strings.isNotBlank(quote.description)) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Description:',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    quote.description,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],

                // ----------------------------------------------------
                pw.Divider(),
              ],
            ),
          );
        }
        return pw.SizedBox();
      },

      build: (context) {
        final content = <pw.Widget>[];

        // Quote-level assumptions
        if (Strings.isNotBlank(quote.assumption)) {
          content.addAll([
            // reduced from 10 to 4
            pw.SizedBox(height: 4),
            pw.Text(
              'Assumptions:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(quote.assumption),
            pw.Divider(),
          ]);
        }

        // Task groups & items with group-level assumptions
        if (displayGroupHeaders) {
          for (final group in visibleGroups) {
            content.addAll([
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    group.group.name,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (displayCosts)
                    pw.Text(
                      group.total.toString(),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ]);

            // Group-level description
            if (Strings.isNotBlank(group.group.description)) {
              content.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, top: 2),
                  child: pw.Text(
                    group.group.description,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
              );
            }

            // Group-level assumption
            if (Strings.isNotBlank(group.group.assumption)) {
              content.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, top: 2),
                  child: pw.Text(
                    'Assumptions: ${group.group.assumption}',
                    style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }

            if (displayItems) {
              for (final line in group.lines) {
                content.add(
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(line.description),
                      if (displayCosts) pw.Text(line.lineTotal.toString()),
                    ],
                  ),
                );
              }
            }
          }
        }

        // Total & payment details
        final showAccount = system.showBsbAccountOnInvoice ?? false;
        final showPaymentLink = system.showPaymentLinkOnInvoice ?? false;
        content.addAll([
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                totalAmount.toString(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ]);

        if (showAccount || showPaymentLink) {
          content
            ..add(pw.Divider())
            ..add(
              pw.Text(
                'Payment Details:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          if (showAccount) {
            content
              ..add(pw.Text('BSB: ${system.bsb}'))
              ..add(pw.Text('Account Number: ${system.accountNo}'));
          }
          if (showPaymentLink) {
            content.add(
              pw.UrlLink(
                child: pw.Text(
                  'Payment Link',
                  style: const pw.TextStyle(
                    color: PdfColors.blue,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
                destination: system.paymentLinkUrl ?? '',
              ),
            );
          }
        }

        if (appendix.isNotEmpty) {
          content
            ..add(pw.NewPage())
            ..add(
              pw.Text(
                'Appendix: Task Photos',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            )
            ..add(pw.SizedBox(height: 8));

          for (final section in appendix) {
            content
              ..add(
                pw.Text(
                  section.taskName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              )
              ..add(pw.SizedBox(height: 4));

            if (Strings.isNotBlank(section.taskDescription)) {
              content
                ..add(pw.Text(section.taskDescription))
                ..add(pw.SizedBox(height: 6));
            }

            for (final photo in section.photos) {
              content.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Image(pw.MemoryImage(photo.bytes)),
                      if (Strings.isNotBlank(photo.comment))
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 4),
                          child: pw.Text('Comment: ${photo.comment}'),
                        ),
                    ],
                  ),
                ),
              );
            }
            content
              ..add(pw.SizedBox(height: 6))
              ..add(pw.Divider())
              ..add(pw.SizedBox(height: 8));
          }
        }

        return content;
      },
    ),
  );

  final output = await getTemporaryDirectory();
  final file = File('${output.path}/quote_${quote.quoteNum ?? quote.id}.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}

bool _isCustomerVisibleQuoteLine(QuoteLine quoteLine) =>
    !quoteLine.description.startsWith('Quote margin (');

Future<List<_QuotePhotoAppendixSection>> _loadQuotePhotoAppendix(
  QuoteDetails quoteDetails,
) async {
  if (quoteDetails.quoteId == 0) {
    return [];
  }

  final selected = await DaoQuoteTaskPhoto().getByQuote(quoteDetails.quoteId);
  if (selected.isEmpty) {
    return [];
  }

  final metasByTask = <int, Map<int, String>>{};
  final taskIds = selected.map((s) => s.taskId).toSet();
  for (final taskId in taskIds) {
    final metas = await DaoPhoto.getByTask(taskId);
    await PhotoMeta.resolveAll(metas);
    final byPhoto = <int, String>{};
    for (final meta in metas) {
      byPhoto[meta.photo.id] = meta.absolutePathTo;
    }
    metasByTask[taskId] = byPhoto;
  }

  final photoById = <int, _ResolvedQuotePhoto>{};
  for (final selection in selected) {
    final path = metasByTask[selection.taskId]?[selection.photoId];
    if (Strings.isBlank(path)) {
      continue;
    }
    final file = File(path!);
    if (!file.existsSync()) {
      continue;
    }
    photoById[selection.photoId] = _ResolvedQuotePhoto(
      bytes: await file.readAsBytes(),
      comment: selection.comment,
    );
  }

  final byTask = <int, List<_QuotePhotoRow>>{};
  for (final selection in selected) {
    final resolved = photoById[selection.photoId];
    if (resolved == null) {
      continue;
    }
    byTask
        .putIfAbsent(selection.taskId, () => [])
        .add(
          _QuotePhotoRow(
            order: selection.displayOrder,
            comment: resolved.comment,
            bytes: resolved.bytes,
          ),
        );
  }

  final sections = <_QuotePhotoAppendixSection>[];
  for (final wrapped in quoteDetails.groups) {
    final group = wrapped.group;
    final taskId = group.taskId;
    if (taskId == null) {
      continue;
    }
    final rows = byTask[taskId];
    if (rows == null || rows.isEmpty) {
      continue;
    }
    rows.sort((a, b) => a.order.compareTo(b.order));
    sections.add(
      _QuotePhotoAppendixSection(
        taskName: group.name,
        taskDescription: group.description,
        photos: rows,
      ),
    );
  }
  return sections;
}

class _ResolvedQuotePhoto {
  final Uint8List bytes;
  final String comment;

  _ResolvedQuotePhoto({required this.bytes, required this.comment});
}

class _QuotePhotoAppendixSection {
  final String taskName;
  final String taskDescription;
  final List<_QuotePhotoRow> photos;

  _QuotePhotoAppendixSection({
    required this.taskName,
    required this.taskDescription,
    required this.photos,
  });
}

class _QuotePhotoRow {
  final int order;
  final String comment;
  final Uint8List bytes;

  _QuotePhotoRow({
    required this.order,
    required this.comment,
    required this.bytes,
  });
}

/// Helper to load and size the business logo
Future<pw.Widget?> _getLogo(System system) async {
  final logoPath = system.logoPath;
  if (Strings.isBlank(logoPath)) {
    return null;
  }
  final file = File(logoPath);
  if (!file.existsSync()) {
    return null;
  }
  final imageData = await file.readAsBytes();
  return pw.Image(
    pw.MemoryImage(imageData),
    width: system.logoAspectRatio.width.toDouble(),
    height: system.logoAspectRatio.height.toDouble(),
  );
}

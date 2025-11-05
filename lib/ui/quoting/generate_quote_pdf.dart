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

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:strings/strings.dart';

import '../../dao/dao_system.dart';
import '../../entity/quote.dart';
import '../../entity/system.dart';
import '../../util/dart/format.dart';
import 'quote_details.dart';

Future<File> generateQuotePdf(
  Quote quote, {
  required bool displayItems,
  required bool displayCosts,
  required bool displayGroupHeaders,
}) async {
  final pdf = pw.Document();
  final system = await DaoSystem().get();
  final jobQuote = await QuoteDetails.fromQuoteId(
    quote.id,
    excludeHidden: true,
  );

  final totalAmount = jobQuote.total;
  final phone = await formatPhone(system.bestPhone);
  final logo = await _getLogo(system);
  final systemColor = PdfColor.fromInt(system.billingColour);

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: pw.EdgeInsets.zero,
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
            padding: const pw.EdgeInsets.fromLTRB(20, 30, 20, 10),
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
                          'Quote: ${quote.bestNumber}',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text('Date: ${formatDate(quote.createdDate)}'),
                      ],
                    ),
                    if (logo != null) logo,
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
          for (final group in jobQuote.groups) {
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

            // Group-level assumption
            if (Strings.isNotBlank(group.group.assumption)) {
              content.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, top: 2),
                  child: pw.Text(
                    group.group.assumption,
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

        return [
          pw.Padding(
            // top padding reduced from 80 to 20
            padding: const pw.EdgeInsets.fromLTRB(20, 20, 20, 60),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: content,
            ),
          ),
        ];
      },
    ),
  );

  final output = await getTemporaryDirectory();
  final file = File('${output.path}/quote_${quote.quoteNum ?? quote.id}.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
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

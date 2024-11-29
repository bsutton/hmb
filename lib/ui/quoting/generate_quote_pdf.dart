import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../dao/dao_quote_line.dart';
import '../../dao/dao_system.dart';
import '../../entity/quote.dart';
import '../../entity/system.dart';
import '../../util/format.dart';
import '../../util/money_ex.dart';
import 'job_quote.dart';

Future<File> generateQuotePdf(
  Quote quote, {
  required bool displayItems,
  required bool displayCosts,
  required bool displayGroupHeaders,
}) async {
  final pdf = pw.Document();
  final system = (await DaoSystem().get())!;

  final lines = await DaoQuoteLine().getByQuoteId(quote.id);

  // Group items by some criteria, e.g., task name or category
  final jobQuote = await JobQuote.fromQuoteId(quote.id);

  // Calculate the total amount from the lines
  final totalAmount =
      lines.fold(MoneyEx.zero, (sum, line) => sum + line.lineTotal);

  final phone = await formatPhone(system.bestPhone);

  // Load logo
  final logo = await _getLogo(system);

  // Define the system color (using the color stored in the system table)
  final systemColor = PdfColor.fromInt(system.billingColour);

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: pw.EdgeInsets.zero,
        buildBackground: (context) => pw.Stack(
          children: [
            // Top coloured band with business name
            pw.Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: pw.Container(
                height: 28, // 1cm height
                color: systemColor,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        system.businessName ?? '',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom coloured band with T&C link
            pw.Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: pw.Container(
                height: 28, // 1cm height
                color: systemColor,
                child: pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 10, right: 10),
                    child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.RichText(
                            text: pw.TextSpan(
                                text: 'This quote is subject to our ',
                                style:
                                    const pw.TextStyle(color: PdfColors.white),
                                children: [
                                  pw.WidgetSpan(
                                    child: pw.UrlLink(
                                      child: pw.Text(
                                        'Terms and Conditions',
                                        style: const pw.TextStyle(
                                          color: PdfColors.blue,
                                          decoration:
                                              pw.TextDecoration.underline,
                                        ),
                                      ),
                                      destination: system.termsUrl ?? '',
                                    ),
                                  ),
                                  const pw.TextSpan(
                                    text: ' and is valid for 30 days',
                                  ),
                                ]),
                          ),
                          pw.Text(
                            '${context.pageNumber} of ${context.pagesCount}',
                            style: const pw.TextStyle(
                                fontSize: 12, color: PdfColors.white),
                          ),
                        ])),
              ),
            ),
          ],
        ),
      ),
      header: (context) {
        if (context.pageNumber == 1) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: 10,
            ), // Prevent overlap with header
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.SizedBox(height: 16),
                            pw.Text(
                              'Quote: ${quote.bestNumber}',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text('Date: ${formatDate(quote.createdDate)}'),
                          ]),

                      // business logo
                      if (logo != null)
                        pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 6),
                            child: logo,
                          ),
                        ),
                    ]),
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
                    '${system.businessNumberLabel}: ${system.businessNumber}'),
                pw.Divider(),
              ],
            ),
          );
        } else {
          return pw.SizedBox(); // Empty header for subsequent pages
        }
      },
      build: (context) {
        final content = <pw.Widget>[];

        if (displayGroupHeaders) {
          /// Display each Task
          for (final group in jobQuote.groups) {
            content
              ..add(pw.SizedBox(height: 10)) // Add 10 units of space
              ..add(pw.Row(
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
                      )
                  ]));
            // Items from the task if requested.
            if (displayItems) {
              for (final line in group.lines) {
                content.add(pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(line.description),
                    if (displayCosts) pw.Text(line.lineTotal.toString()),
                  ],
                ));
              }
            }
          }
        }

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
          pw.Divider(),

          // Payment details
          if (showPaymentLink || showAccount)
            pw.Text(
              'Payment Details:',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          if (showAccount) ...[
            pw.Text('BSB: ${system.bsb}'),
            pw.Text('Account Number: ${system.accountNo}'),
          ],
          if (showPaymentLink) ...[
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
          ],
        ]);

        return [
          pw.Padding(
              padding: const pw.EdgeInsets.only(
                left: 20,
                right: 20,
                top: 80, // Ensure space from top band
                bottom: 60, // Ensure space from bottom band
              ),
              child: pw.Column(
                  children: content,
                  crossAxisAlignment: pw.CrossAxisAlignment.start))
        ]; // Indent for body content
      },
    ),
  );

  final output = await getTemporaryDirectory();
  final file = File('${output.path}/quote_${quote.quoteNum ?? quote.id}.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}

// Helper function to get the logo
Future<pw.Widget?> _getLogo(System system) async {
  final logoPath = system.logoPath;

  if (logoPath.isEmpty) {
    return null;
  }

  final file = File(logoPath);
  if (!file.existsSync()) {
    return null;
  }
  final image = pw.MemoryImage(await file.readAsBytes());

  return pw.Image(image,
      width: system.logoAspectRatio.width.toDouble(),
      height: system.logoAspectRatio.height.toDouble());
}

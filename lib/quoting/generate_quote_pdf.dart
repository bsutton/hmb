import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../dao/dao_quote_line.dart';
import '../dao/dao_system.dart';
import '../entity/quote.dart';
import '../entity/quote_line.dart';
import '../entity/system.dart';
import '../util/format.dart';
import '../util/money_ex.dart';

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
  final groupedLines = _groupLinesByTask(lines);

  // Calculate the total amount from the lines
  final totalAmount =
      lines.fold(MoneyEx.zero, (sum, line) => sum + line.lineTotal);

  final phone = await formatPhone(system.bestPhone);

  // Load logo
  final logo = await _getLogo(system);

  // Define the system color (using the color stored in the system table)
  final systemColor = PdfColor.fromInt(system.billingColour);

  pdf.addPage(
    pw.Page(
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.symmetric(
            horizontal: 40), // Left and right margins
        buildBackground: (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Stack(
            children: [
              // Top band
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
              // Bottom band with T&C link
              pw.Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: pw.Container(
                  height: 28, // 1cm height
                  color: systemColor,
                  child: pw.Center(
                    child: pw.RichText(
                      text: pw.TextSpan(
                          text: 'This quote is subject to our ',
                          style: const pw.TextStyle(color: PdfColors.white),
                          children: [
                            pw.WidgetSpan(
                                child: pw.UrlLink(
                              child: pw.Text(
                                'Terms and Conditions',
                                style: const pw.TextStyle(
                                  color: PdfColors.blue,
                                  decoration: pw.TextDecoration.underline,
                                ),
                              ),
                              destination: system.termsUrl ?? '',
                            )),
                            const pw.TextSpan(text: ' and is valid for 30 days')
                          ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 36), // Space to move content below the top band
          if (logo != null)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8, right: 16),
                child: logo,
              ),
            ),
          pw.SizedBox(height: 16),
          pw.Text('Quote: ${quote.bestNumber}',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text('Date: ${formatDate(quote.createdDate)}'),
          pw.Divider(),
          pw.Text('Business Details:',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Business Name: ${system.businessName}'),
          pw.Text('Address: ${system.address}'),
          pw.Text('Email: ${system.emailAddress}'),
          pw.Text('Phone: $phone'),
          pw.Text('${system.businessNumberLabel}: ${system.businessNumber}'),
          pw.Divider(),

          // Display grouped items
          if (displayGroupHeaders)
            ...groupedLines.entries.map((entry) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(entry.key,
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    if (displayItems)
                      ...entry.value.map((line) => pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(line.description),
                              if (displayCosts)
                                pw.Text(line.lineTotal.toString()),
                            ],
                          )),
                  ],
                )),

          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(totalAmount.toString(),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Divider(),
          pw.Text('Payment Details:',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          if (system.showBsbAccountOnInvoice ?? false) ...[
            pw.Text('BSB: ${system.bsb}'),
            pw.Text('Account Number: ${system.accountNo}'),
          ],
          if (system.showPaymentLinkOnInvoice ?? false) ...[
            pw.UrlLink(
              child: pw.Text('Payment Link',
                  style: const pw.TextStyle(
                    color: PdfColors.blue,
                    decoration: pw.TextDecoration.underline,
                  )),
              destination: system.paymentLinkUrl ?? '',
            ),
          ],
          pw.SizedBox(height: 36), // Space above the bottom band
        ],
      ),
    ),
  );

  final output = await getTemporaryDirectory();
  final file = File('${output.path}/quote_${quote.quoteNum ?? quote.id}.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}

// Helper function to group lines by task or category
Map<String, List<QuoteLine>> _groupLinesByTask(List<QuoteLine> lines) {
  final grouped = <String, List<QuoteLine>>{};
  for (final line in lines) {
    grouped.putIfAbsent(line.description, () => []).add(line);
  }
  return grouped;
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
      width: system.logoType.width.toDouble(),
      height: system.logoType.height.toDouble());
}

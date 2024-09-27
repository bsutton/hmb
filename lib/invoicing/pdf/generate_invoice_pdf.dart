import 'dart:io';

import 'package:money2/money2.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../dao/_index.g.dart';
import '../../entity/_index.g.dart';
import '../../util/format.dart';
import '../../util/money_ex.dart';

Future<File> generateInvoicePdf(
  Invoice invoice, {
  required bool displayItems,
  required bool displayCosts,
  required bool displayGroupHeaders,
}) async {
  final pdf = pw.Document();
  final system = (await DaoSystem().get())!;
  final lines = await DaoInvoiceLine().getByInvoiceId(invoice.id);

  // Calculate the total amount from lines, excluding noChargeHidden lines
  final totalAmount = lines
      .where((line) => line.status != LineStatus.noChargeHidden)
      .fold(MoneyEx.zero, (sum, line) => sum + line.lineTotal);

  final phone = await formatPhone(system.bestPhone);

  // Load logo
  final logo = await _getLogo(system);

  // Define the system color (using the color stored in the system table)
  final systemColor = PdfColor.fromInt(system.billingColour);

  var groupedLines = <GroupedLine>[];

  if (displayGroupHeaders) {
    // Group items by `invoiceLineGroupId`
    groupedLines = await groupByInvoiceLineGroup(lines);
  }

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: pw.EdgeInsets.zero,
        buildBackground: (context) => pw.Stack(
          children: [
            // Top colored band with business name
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
            // Bottom colored band with page number
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
            padding: const pw.EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: 10,
            ),
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
                          'Invoice: ${invoice.bestNumber}',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text('Date: ${formatDate(invoice.createdDate)}'),
                        pw.Text(
                          'Due Date: ${formatLocalDate(invoice.dueDate)}',
                        ),
                      ],
                    ),
                    // Business logo
                    if (logo != null)
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 6),
                          child: logo,
                        ),
                      ),
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
                    '${system.businessNumberLabel}: ${system.businessNumber}'),
                pw.Divider(),
              ],
            ),
          );
        } else {
          return pw.SizedBox();
        }
      },
      build: (context) {
        final content = <pw.Widget>[];

        if (displayGroupHeaders) {
          // Group items by `invoiceLineGroupId`

          for (final group in groupedLines) {
            content
              ..add(pw.SizedBox(height: 10)) // Add 10 units of space
              ..add(pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      group.key == null ? 'Ungrouped' : group.title,
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
                  ]));

            // Display items in the group if requested
            if (displayItems) {
              for (final line in group.items) {
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
        } else {
          // Display lines without grouping if group headers are not enabled
          for (final line in lines) {
            content.add(pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(line.description),
                if (displayCosts) pw.Text(line.lineTotal.toString()),
              ],
            ));
          }
        }

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
          if (system.showBsbAccountOnInvoice ?? false) ...[
            pw.Text('Payment Details:'),
            pw.Text('BSB: ${system.bsb}'),
            pw.Text('Account Number: ${system.accountNo}'),
          ],
          if (system.showPaymentLinkOnInvoice ?? false) ...[
            pw.UrlLink(
              child: pw.Text(
                'Pay Now',
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
              crossAxisAlignment: pw.CrossAxisAlignment.start,
            ),
          ),
        ];
      },
    ),
  );

  final output = await getTemporaryDirectory();
  final file = File('${output.path}/invoice_${invoice.invoiceNum}.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}

// Helper function to group items by `invoiceLineGroupId`
Future<List<GroupedLine>> groupByInvoiceLineGroup(
    List<InvoiceLine> lines) async {
  final grouped = <int?, List<InvoiceLine>>{};
  for (final line in lines) {
    final groupKey = line.invoiceLineGroupId;
    grouped.putIfAbsent(groupKey, () => []).add(line);
  }

  // Convert the map to a list of grouped lines
  final groupLines = <GroupedLine>[];
  for (final entry in grouped.entries) {
    final total =
        entry.value.fold(MoneyEx.zero, (sum, line) => sum + line.lineTotal);
    groupLines.add(GroupedLine(
        key: entry.key,
        title: (await DaoInvoiceLineGroup().getById(entry.key))!.name,
        items: entry.value,
        total: total));
  }

  return groupLines;
}

// Grouped line class to hold grouping data
class GroupedLine {
  GroupedLine({
    required this.key,
    required this.title,
    required this.items,
    required this.total,
  });

  final int? key;
  final String title;
  final List<InvoiceLine> items;
  final Money total;
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

  return pw.Image(
    image,
    width: system.logoAspectRatio.width.toDouble(),
    height: system.logoAspectRatio.height.toDouble(),
  );
}

import 'dart:io';

import 'package:money2/money2.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/format.dart';
import '../../../util/money_ex.dart';

Future<File> generateInvoicePdf(
  Invoice invoice, {
  required bool displayItems,
  required bool displayCosts,
  required bool displayGroupHeaders,
}) async {
  final pdf = pw.Document();
  final system = await DaoSystem().get();
  final lines = await DaoInvoiceLine().getByInvoiceId(invoice.id);

  // Calculate the total amount from lines, excluding noChargeHidden lines
  final totalAmount = lines
      .where((line) => line.status != LineChargeableStatus.noChargeHidden)
      .fold(MoneyEx.zero, (sum, line) => sum + line.lineTotal);

  final phone = await formatPhone(system.bestPhone);

  // Load logo
  final logo = await _getLogo(system);

  // Define the system color (using the color stored in the system table)
  final systemColor = PdfColor.fromInt(system.billingColour);

  // Retrieve the Job using the jobId from the Invoice.
  final job = (await DaoJob().getById(invoice.jobId))!;

  // Retrieve the customer for the job and the primary contact for the job.
  final customer = await DaoCustomer().getByJob(invoice.jobId);
  var billingContact = await DaoContact().getById(invoice.billingContactId);
  billingContact ??= await DaoContact().getBillingContactByJob(job);

  // Group lines if requested
  var groupedLines = <GroupedLine>[];
  if (displayGroupHeaders) {
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
                height: 28,
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
                // Top row: Tax Invoice details on the left and customer/contact on the right
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Left column: Invoice details
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(height: 16),
                        pw.Text(
                          'Tax Invoice: ${invoice.bestNumber}',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Issued: ${formatDate(invoice.createdDate, format: 'Y M d')}',
                        ),
                        pw.Text(
                          'Due Date: ${formatLocalDate(invoice.dueDate, 'yyyy MMM dd')}',
                        ),
                      ],
                    ),
                    // Right column: Customer and Contact details
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.SizedBox(height: 16),
                        if (customer != null)
                          pw.Text(
                            'To: ${customer.name}',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        if (billingContact != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Attention: ${billingContact.fullname}',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                pw.Divider(),
                // Business details and logo in one row
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Business details on the left
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            system.businessName ?? '',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (system.address.isNotEmpty)
                            pw.Text('Address: ${system.address}'),
                          if (system.emailAddress != null &&
                              system.emailAddress!.isNotEmpty)
                            pw.Text('Email: ${system.emailAddress}'),
                          if (phone.isNotEmpty) pw.Text('Phone: $phone'),
                          if (system.businessNumberLabel != null &&
                              system.businessNumber != null &&
                              system.businessNumber!.isNotEmpty)
                            pw.Text(
                              '${system.businessNumberLabel}: ${system.businessNumber}',
                            ),
                        ],
                      ),
                    ),
                    // Logo on the right
                    if (logo != null) logo,
                  ],
                ),
                pw.Divider(),
                // Job details
                pw.Text(
                  'Job: #${job.id}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(job.summary, style: const pw.TextStyle(fontSize: 12)),
                pw.Divider(),
              ],
            ),
          );
        }
        return pw.SizedBox();
      },
      build: (context) {
        final content = <pw.Widget>[];

        if (displayGroupHeaders) {
          for (final group in groupedLines) {
            content
              ..add(pw.SizedBox(height: 10))
              ..add(
                pw.Row(
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
                  ],
                ),
              );
            if (displayItems) {
              for (final line in group.items) {
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
        } else {
          for (final line in lines) {
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
          pw.SizedBox(height: 10),
          pw.Text(
            paymentTerms(system),
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.Text(
            'Payment Options: ${system.paymentOptions}',
            style: const pw.TextStyle(fontSize: 12),
          ),
        ]);

        return [
          pw.Padding(
            padding: const pw.EdgeInsets.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 20,
            ),
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
  final file = File('${output.path}/invoice_${invoice.bestNumber}.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}

String paymentTerms(System system) {
  if (system.paymentTermsInDays == 0) {
    return 'Payment Terms: immediate';
  } else {
    return 'Payment Terms: ${system.paymentTermsInDays} days';
  }
}

Future<List<GroupedLine>> groupByInvoiceLineGroup(
  List<InvoiceLine> lines,
) async {
  final grouped = <int?, List<InvoiceLine>>{};
  for (final line in lines) {
    final groupKey = line.invoiceLineGroupId;
    grouped.putIfAbsent(groupKey, () => []).add(line);
  }

  final groupLines = <GroupedLine>[];
  for (final entry in grouped.entries) {
    final total = entry.value.fold(
      MoneyEx.zero,
      (sum, line) => sum + line.lineTotal,
    );
    final groupLine = GroupedLine(
      key: entry.key,
      title: (await DaoInvoiceLineGroup().getById(entry.key))!.name,
      items: entry.value,
      total: total,
    );

    if (groupLine.hasVisibleItems) {
      groupLines.add(groupLine);
    }
  }

  return groupLines;
}

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

  Fixed get quantity =>
      items.map((line) => line.quantity).reduce((lhs, rhs) => lhs + rhs);

  bool get hasVisibleItems => items
      .where((item) => item.status != LineChargeableStatus.noChargeHidden)
      .isNotEmpty;
}

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

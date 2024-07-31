import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../dao/dao_quote_line.dart';
import '../dao/dao_system.dart';
import '../entity/quote.dart';
import '../util/format.dart';
import '../util/money_ex.dart';

Future<File> generateQuotePdf(Quote quote) async {
  final pdf = pw.Document();
  final system = await DaoSystem().get();

  final lines = await DaoQuoteLine().getByQuoteId(quote.id);

  // Calculate the total amount from the lines
  final totalAmount =
      lines.fold(MoneyEx.zero, (sum, line) => sum + line.lineTotal);

  final phone = await formatPhone(system?.bestPhone);

  pdf.addPage(
    pw.Page(
      build: (context) => pw.Column(
        children: [
          pw.Text('Quote: ${quote.bestNumber}'),
          pw.Text('Date: ${formatDate(quote.createdDate)}'),
          pw.Text('Total Amount: ${quote.totalAmount}'),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Business Details:'),
                pw.Text('Business Name: ${system!.businessName}'),
                pw.Text('''Address: ${system.address}'''),
                pw.Text('Email: ${system.emailAddress}'),
                pw.Text('Phone: $phone'),
                pw.Text(
                    '${system.businessNumberLabel}: ${system.businessNumber}'),
              ],
            ),
          ),
          pw.Divider(),
          ...lines.map((line) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(line.description),
                  pw.Text(line.lineTotal.toString()),
                ],
              )),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total:'),
              pw.Text(totalAmount.toString()),
            ],
          ),
          pw.Divider(),
          pw.Text('Payment Details:'),
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
        ],
      ),
    ),
  );

  final output = await getTemporaryDirectory();
  final file = File('${output.path}/quote_${quote.quoteNum ?? quote.id}.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}

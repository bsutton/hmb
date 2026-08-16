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

@Tags(['flutter'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/accounting_report_service.dart';
import 'package:hmb/ui/nav/dashboards/accounting/debtor_statement_pdf.dart'
    as statement_pdf;
import 'package:hmb/ui/nav/dashboards/accounting/report_csv_export.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../../../../database/management/db_utility_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test('overflowing accounting report generates multiple PDF pages', () async {
    final rows = <List<String>>[
      ['Date', 'Description', 'Amount'],
      for (var index = 1; index <= 50; index++)
        ['2026-08-12', 'Pagination test row $index', r'$10.00'],
    ];

    final file = await buildReportPdfFile(
      fileName: 'pagination_test_report.pdf',
      title: 'Pagination test report',
      rows: rows,
    );
    addTearDown(() => file.parent.deleteSync(recursive: true));

    expect(_pdfPageCount(await file.readAsBytes()), greaterThan(1));
  });

  test('overflowing statement generates multiple PDF pages', () async {
    final rows = [
      for (var index = 1; index <= 50; index++)
        DebtorStatementPdfRow(
          date: '2026-08-12',
          invoiceNumber: '$index',
          description: 'Pagination test row $index',
          amount: r'$10.00',
        ),
    ];

    final bytes = await buildDebtorStatementPdfBytes(
      title: 'Pagination test statement',
      customerName: 'Pat Customer',
      period: 'August 2026',
      openingBalance: r'$0.00',
      closingBalance: r'$1,000.00',
      rows: rows,
    );

    expect(_pdfPageCount(bytes), greaterThan(1));
  });

  test(
    'overflowing debtor statement keeps generating multiple pages',
    () async {
      final report = DebtorStatementReport(
        customerId: 1,
        customerName: 'Pat Customer',
        startInclusive: DateTime(2026, 8),
        endExclusive: DateTime(2026, 9),
        openingBalance: MoneyEx.zero,
        entries: [
          for (var index = 1; index <= 50; index++)
            DebtorStatementEntry(
              type: DebtorStatementEntryType.invoice,
              invoiceId: index,
              invoiceNumber: '$index',
              customerName: 'Pat Customer',
              date: DateTime(2026, 8, 12),
              description: 'Pagination test row $index',
              amount: MoneyEx.dollars(10),
            ),
        ],
      );
      final file = await statement_pdf.buildDebtorStatementPdfFile(
        fileName: 'pagination_test.pdf',
        report: report,
      );
      addTearDown(() => file.parent.deleteSync(recursive: true));

      expect(_pdfPageCount(await file.readAsBytes()), greaterThan(1));
    },
  );
}

int _pdfPageCount(Uint8List bytes) {
  final source = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r'/Type\s*/Page(?!s)\b').allMatches(source).length;
}

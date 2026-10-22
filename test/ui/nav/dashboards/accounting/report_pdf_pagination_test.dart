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
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/accounting_report_service.dart';
import 'package:hmb/ui/nav/dashboards/accounting/debtor_statement_pdf.dart'
    as statement_pdf;
import 'package:hmb/ui/nav/dashboards/accounting/report_csv_export.dart';
import 'package:hmb/ui/nav/dashboards/accounting/statement_balance_label.dart';
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

  test('overpayment statement PDF keeps its signed credit total', () async {
    final report = DebtorStatementReport(
      customerId: 1,
      customerName: 'Synthetic Customer',
      startInclusive: DateTime(2026, 8),
      endExclusive: DateTime(2026, 9),
      openingBalance: MoneyEx.zero,
      entries: [
        DebtorStatementEntry(
          type: DebtorStatementEntryType.invoice,
          invoiceId: 1,
          invoiceNumber: 'SYN-1',
          customerName: 'Synthetic Customer',
          date: DateTime(2026, 8, 12),
          description: 'Invoice issued',
          amount: MoneyEx.dollars(100),
        ),
        DebtorStatementEntry(
          type: DebtorStatementEntryType.payment,
          invoiceId: 0,
          invoiceNumber: '',
          customerName: 'Synthetic Customer',
          date: DateTime(2026, 8, 13),
          description: 'Payment received',
          amount: -MoneyEx.dollars(125),
        ),
      ],
    );
    final file = await statement_pdf.buildDebtorStatementPdfFile(
      fileName: 'synthetic_credit_statement.pdf',
      report: report,
    );
    addTearDown(() => file.parent.deleteSync(recursive: true));

    expect(report.closingBalance, -MoneyEx.dollars(25));
    expect(statementBalanceLabel(report.closingBalance), 'Credit balance');
    expect(statementBalanceLabel(MoneyEx.dollars(60)), 'Balance due');
    expect(statementBalanceLabel(MoneyEx.zero), 'Balance due');
    expect(await file.length(), greaterThan(0));
    if (Platform.isLinux && File('/usr/bin/pdftotext').existsSync()) {
      final result = await Process.run('pdftotext', [file.path, '-']);
      expect(result.exitCode, 0);
      final text = result.stdout as String;
      expect(text, contains('CREDIT BALANCE'));
      expect(text, contains(report.closingBalance.toString()));
      expect(text, isNot(contains('BALANCE DUE')));
      expect(text, isNot(contains('How to pay')));
    }
  });
}

int _pdfPageCount(Uint8List bytes) {
  final source = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r'/Type\s*/Page(?!s)\b').allMatches(source).length;
}

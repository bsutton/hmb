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

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/quoting/generate_quote_pdf.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory outputDirectory;

  setUp(() async {
    outputDirectory = Directory.systemTemp.createTempSync(
      'hmb_quote_pdf_test_',
    );
    PathProviderPlatform.instance = _FakePathProvider(outputDirectory.path);
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
    outputDirectory.deleteSync(recursive: true);
  });

  test('overflowing quote generates multiple PDF pages', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.fixedPrice,
      hourlyRate: MoneyEx.dollars(100),
      bookingFee: MoneyEx.zero,
    );
    final quote = Quote.forInsert(
      jobId: job.id,
      summary: 'Quote pagination test',
      description: '',
      totalAmount: MoneyEx.dollars(550),
    );
    await DaoQuote().insert(quote);

    final group = QuoteLineGroup.forInsert(
      quoteId: quote.id,
      taskId: null,
      name: 'Test items',
    );
    await DaoQuoteLineGroup().insert(group);

    for (var index = 1; index <= 55; index++) {
      await DaoQuoteLine().insert(
        QuoteLine.forInsert(
          quoteId: quote.id,
          quoteLineGroupId: group.id,
          description: 'Pagination test item $index',
          quantity: Fixed.one,
          unitCharge: MoneyEx.dollars(10),
          lineTotal: MoneyEx.dollars(10),
        ),
      );
    }

    final file = await generateQuotePdf(
      quote,
      displayItems: true,
      displayCosts: true,
      displayGroupHeaders: true,
    );

    expect(file.existsSync(), isTrue);
    expect(await _pdfPageCount(file), greaterThan(1));
  });
}

Future<int> _pdfPageCount(File file) async {
  final source = latin1.decode(await file.readAsBytes(), allowInvalid: true);
  return RegExp(r'/Type\s*/Page(?!s)\b').allMatches(source).length;
}

class _FakePathProvider
    with Fake, MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

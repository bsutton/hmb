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

import 'package:money2/money2.dart';

import '../../dao/dao_quote_line.dart';
import '../../dao/dao_quote_line_group.dart';
import '../../entity/invoice_line.dart';
import '../../entity/quote_line.dart';
import '../../entity/quote_line_group.dart';
import '../../util/dart/money_ex.dart';

class JobQuote {
  final int quoteId;
  final List<QuoteLineGroupWithLines> groups;

  JobQuote({required this.quoteId, required this.groups});

  Money get total =>
      groups.fold(MoneyEx.zero, (sum, group) => sum + group.total);

  static Future<JobQuote> fromQuoteId(
    int quoteId, {
    required bool excludeHidden,
  }) async {
    final quoteLineGroups = await DaoQuoteLineGroup().getByQuoteId(quoteId);
    final groupsWithLines = await Future.wait(
      quoteLineGroups.map((group) async {
        final lines = await DaoQuoteLine().getByQuoteLineGroupId(group.id);

        final filteredLines = excludeHidden
            ? lines.where(
                (line) =>
                    line.lineChargeableStatus == LineChargeableStatus.normal,
              )
            : lines;
        return QuoteLineGroupWithLines(
          group: group,
          lines: filteredLines.toList(),
        );
      }).toList(),
    );

    final filteredGroups = excludeHidden
        ? groupsWithLines.where((group) => group.hasVisible)
        : groupsWithLines;

    return JobQuote(quoteId: quoteId, groups: filteredGroups.toList());
  }
}

class QuoteLineGroupWithLines {
  final QuoteLineGroup group;
  final List<QuoteLine> lines;

  QuoteLineGroupWithLines({required this.group, required this.lines});

  Money get total => lines
      .where((line) => line.lineChargeableStatus == LineChargeableStatus.normal)
      .fold(MoneyEx.zero, (running, line) => running + line.lineTotal);

  bool get hasVisible => lines
      .where((line) => line.lineChargeableStatus == LineChargeableStatus.normal)
      .isNotEmpty;
}

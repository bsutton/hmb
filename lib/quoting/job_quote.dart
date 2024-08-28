import 'package:money2/money2.dart';

import '../dao/dao_quote_line.dart';
import '../dao/dao_quote_line_group.dart';
import '../entity/quote_line.dart';
import '../entity/quote_line_group.dart';
import '../util/money_ex.dart';

class JobQuote {
  JobQuote({
    required this.quoteId,
    required this.groups,
  });
  final int quoteId;
  final List<QuoteLineGroupWithLines> groups;

  static Future<JobQuote> fromQuoteId(int quoteId) async {
    final quoteLineGroups = await DaoQuoteLineGroup().getByQuoteId(quoteId);
    final groupsWithLines = await Future.wait(
      quoteLineGroups.map((group) async {
        final lines = await DaoQuoteLine().getByQuoteLineGroupId(group.id);
        return QuoteLineGroupWithLines(group: group, lines: lines);
      }).toList(),
    );

    return JobQuote(
      quoteId: quoteId,
      groups: groupsWithLines,
    );
  }
}

class QuoteLineGroupWithLines {
  QuoteLineGroupWithLines({
    required this.group,
    required this.lines,
  });
  final QuoteLineGroup group;
  final List<QuoteLine> lines;

  Money get total => lines.fold(
        MoneyEx.zero,
        (running, line) => running + line.lineTotal,
      );
}

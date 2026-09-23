@Tags(['flutter'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/base_full_screen/list_entity_screen.dart';
import 'package:hmb/ui/widgets/hmb_search.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  testWidgets('a stale refresh cannot hide a newly saved quote', (
    tester,
  ) async {
    final pendingRefresh = Completer<List<Quote>>();
    final savedQuote = Completer<Quote?>();
    var fetchCount = 0;
    final quote = Quote.forInsert(
      jobId: 1,
      summary: 'New estimate quote',
      description: '',
      totalAmount: MoneyEx.zero,
    )..id = 42;
    await tester.pumpWidget(
      MaterialApp(
        home: EntityListScreen<Quote>(
          entityNameSingular: 'Quote',
          entityNamePlural: 'Quotes',
          dao: DaoQuote(),
          fetchList: (_) {
            fetchCount++;
            return fetchCount == 1
                ? Future.value(<Quote>[])
                : pendingRefresh.future;
          },
          onAdd: () => savedQuote.future,
          listCardTitle: (quote) => Text(quote.summary),
          listCard: (_) => const SizedBox(height: 100),
          onEdit: (_) => const SizedBox.shrink(),
          canEdit: (_) => false,
          canDelete: (_) => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<HMBSearchWithAdd>(find.byType(HMBSearchWithAdd)).onAdd();
    final state = tester.state<EntityListScreenState<Quote>>(
      find.byType(EntityListScreen<Quote>),
    );
    // Closing the task-selection dialog can start a route-return refresh
    // before the new quote has finished saving.
    final refreshing = state.refresh();
    savedQuote.complete(quote);
    await tester.pumpAndSettle();
    expect(find.text('New estimate quote'), findsOneWidget);
    pendingRefresh.complete([]);
    await refreshing;
    await tester.pumpAndSettle();
    expect(find.text('New estimate quote'), findsOneWidget);
    expect(state.entityList.single.id, 42);
  });

  testWidgets('the newest search wins when requests complete out of order', (
    tester,
  ) async {
    final older = Completer<List<Quote>>();
    final newer = Completer<List<Quote>>();
    var fetchCount = 0;
    final quote = Quote.forInsert(
      jobId: 1,
      summary: 'Current search result',
      description: '',
      totalAmount: MoneyEx.zero,
    )..id = 42;
    await tester.pumpWidget(
      MaterialApp(
        home: EntityListScreen<Quote>(
          entityNameSingular: 'Quote',
          entityNamePlural: 'Quotes',
          dao: DaoQuote(),
          fetchList: (_) => switch (++fetchCount) {
            1 => Future.value(<Quote>[]),
            2 => older.future,
            _ => newer.future,
          },
          listCardTitle: (quote) => Text(quote.summary),
          listCard: (_) => const SizedBox(height: 100),
          onEdit: (_) => const SizedBox.shrink(),
          canEdit: (_) => false,
          canDelete: (_) => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state<EntityListScreenState<Quote>>(
      find.byType(EntityListScreen<Quote>),
    );
    final first = state.refresh();
    final second = state.refresh();
    newer.complete([quote]);
    await second;
    older.complete([]);
    await first;
    await tester.pumpAndSettle();
    expect(find.text('Current search result'), findsOneWidget);
  });
}

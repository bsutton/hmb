import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/milestone/milestone_tile.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

void main() {
  testWidgets('voided milestone shows label and hides invoice', (tester) async {
    final milestone = Milestone.forInsert(
      quoteId: 1,
      milestoneNumber: 1,
      paymentAmount: MoneyEx.dollars(100),
      paymentPercentage: Percentage.fromInt(50),
      milestoneDescription: 'Milestone 1',
      voided: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MilestoneTile(
            milestone: milestone,
            quoteTotal: MoneyEx.dollars(200),
            onDelete: (_) {},
            onSave: (_) {},
            onInvoice: (_) async {},
            canEdit: false,
            onEditingStatusChanged:
                ({required milestone, required isEditing}) {},
            isOtherTileEditing: false,
          ),
        ),
      ),
    );

    expect(find.text('Voided'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('editable milestone shows invoice button', (tester) async {
    final milestone = Milestone.forInsert(
      quoteId: 1,
      milestoneNumber: 1,
      paymentAmount: MoneyEx.dollars(100),
      paymentPercentage: Percentage.fromInt(50),
      milestoneDescription: 'Milestone 1',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MilestoneTile(
            milestone: milestone,
            quoteTotal: MoneyEx.dollars(200),
            onDelete: (_) {},
            onSave: (_) {},
            onInvoice: (_) async {},
            canEdit: true,
            onEditingStatusChanged:
                ({required milestone, required isEditing}) {},
            isOtherTileEditing: false,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}

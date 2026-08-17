@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/hmb_search.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('search with add leaves trailing screen padding', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 393,
            child: HMBSearchWithAdd(onSearch: (_) {}, onAdd: () {}),
          ),
        ),
      ),
    );

    final addRight = tester.getTopRight(find.byIcon(Icons.add)).dx;

    expect(393 - addRight, greaterThanOrEqualTo(8));
  });
}

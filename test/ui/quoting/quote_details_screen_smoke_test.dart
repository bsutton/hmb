@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pumpWidget smoke', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
  });
}

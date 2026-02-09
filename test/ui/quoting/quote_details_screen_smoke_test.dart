import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pumpWidget smoke', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
  });
}

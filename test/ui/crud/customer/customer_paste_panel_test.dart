import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/crud/customer/customer_paste_panel.dart';

void main() {
  testWidgets('mobile actions use short labels and remain side by side', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const helperText =
        'Paste a customer message to extract the job details using AI, or skip '
        'extraction and enter the job details manually';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerPastePanel(
            initialMessage: '',
            helperText: helperText,
            skipLabel: 'Skip',
            onSkip: () {},
            onExtract: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(helperText), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Extract'), findsOneWidget);

    final skipCenter = tester.getCenter(find.text('Skip'));
    final extractCenter = tester.getCenter(find.text('Extract'));
    expect(skipCenter.dy, extractCenter.dy);
    expect(skipCenter.dx, lessThan(extractCenter.dx));
  });
}

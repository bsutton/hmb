import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/wizard.dart';
import 'package:hmb/ui/widgets/wizard_step.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final scrollToBottom in [false, true]) {
    testWidgets('long wizard step advances visibly: $scrollToBottom', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wizard(
              initialSteps: [
                _TestStep('Capture', 100),
                _TestStep('Receipt Lines', 6000),
                _TestStep('Totals', 100),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Receipt Lines content').hitTestable(), findsOneWidget);
      if (scrollToBottom) {
        final scroll = tester
            .widget<ListView>(find.byType(ListView))
            .controller!;
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Totals content').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Receipt Lines content').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
    });
  }
}

class _TestStep extends WizardStep {
  final String name;
  final double height;

  _TestStep(this.name, this.height) : super(title: name);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Align(alignment: Alignment.topLeft, child: Text('$name content')),
  );
}

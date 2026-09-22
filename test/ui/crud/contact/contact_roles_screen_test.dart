import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/crud/contact/contact_roles_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await setupTestDb();
  });
  tearDown(tearDownTestDb);

  testWidgets('role dialog fits its content and scrolls above the keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: ContactRolesScreen()));
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.text('Add role type').evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.tap(find.text('Add role type'));
    await tester.pumpAndSettle();
    final dialogSurface = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.type == MaterialType.card,
      ),
    );
    expect(tester.getSize(dialogSurface).height, lessThan(400));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a Role name'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 500);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Save').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}

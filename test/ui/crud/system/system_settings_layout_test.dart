@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/crud/system/chatgpt_integration_screen.dart';
import 'package:hmb/ui/crud/system/ihserver_integration_screen.dart';
import 'package:hmb/ui/crud/system/system_storage_screen.dart';
import 'package:hmb/ui/crud/system/xero_integration_screen.dart';

import '../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  for (final scenario in const [
    _ScreenScenario(
      name: 'ihserver integration',
      screen: IhServerIntegrationScreen(),
      firstField: 'ihserver Base URL',
    ),
    _ScreenScenario(
      name: 'ChatGPT integration',
      screen: ChatGptIntegrationScreen(),
      firstField: 'OpenAI API Key',
    ),
    _ScreenScenario(
      name: 'Xero integration',
      screen: XeroIntegrationScreen(),
      firstField: 'Xero Client ID',
    ),
    _ScreenScenario(
      name: 'storage',
      screen: SystemStorageScreen(),
      firstField: 'Photo Cache Size (MB)',
    ),
  ]) {
    testWidgets('${scenario.name} uses padded scrolling content', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: scenario.screen));
      await _pumpUntilVisible(tester, scenario.firstField);

      final listView = tester.widget<ListView>(find.byType(ListView));

      expect(listView.padding, const EdgeInsets.all(16));
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpUntilVisible(WidgetTester tester, String text) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    final exception = tester.takeException();
    if (exception != null) {
      fail('Settings screen failed to initialise: $exception');
    }
    if (find.text(text).evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 1));
      return;
    }
  }
  fail('Settings screen did not render "$text".');
}

class _ScreenScenario {
  final String name;
  final Widget screen;
  final String firstField;

  const _ScreenScenario({
    required this.name,
    required this.screen,
    required this.firstField,
  });
}

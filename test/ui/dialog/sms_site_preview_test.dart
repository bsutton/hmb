@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_message_template.dart';
import 'package:hmb/entity/message_template.dart';
import 'package:hmb/entity/site.dart';
import 'package:hmb/ui/dialog/message_template_dialog.dart';
import 'package:hmb/ui/dialog/source_context.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:material_ui/material_ui.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  for (final missing in [false, true]) {
    testWidgets('SMS preview and selection agree (missing site: $missing)', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await DaoMessageTemplate().insert(
          MessageTemplate.forInsert(
            title: '654 Preview regression',
            message: 'My custom wording',
            messageType: MessageType.sms,
          ),
        );
      });
      final site = missing
          ? null
          : Site.forInsert(
              addressLine1: '22 Work Street',
              addressLine2: '',
              suburb: 'Richmond',
              state: 'VIC',
              postcode: '3121',
              accessDetails: null,
            );
      SelectedMessageTemplate? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showMessageTemplateDialog(
                    context,
                    sourceContext: _FixedSiteContext(site),
                    messageType: MessageType.sms,
                  );
                },
                child: const Text('Compose'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Compose'));
      await pumpUntilFound(tester, find.text('Choose a template'));
      await tester.tap(find.byType(HMBDroplist<MessageTemplate>));
      await pumpUntilFound(tester, find.text('654 Preview regression'));
      await tester.tap(find.text('654 Preview regression'));
      final editor = find.widgetWithText(TextFormField, 'Edit Message');
      await pumpUntilCondition(
        tester,
        () => tester
            .widget<TextFormField>(editor)
            .controller!
            .text
            .startsWith('My custom wording'),
        'template editor to update',
      );
      expect(
        tester.widget<TextFormField>(editor).controller!.text,
        'My custom wording\n\nSite: {{site.address}}',
      );
      await tester.enterText(editor, 'Edited wording\nSite: {{site.address}}');
      await tester.pump();
      await tester.tap(find.text('Preview'));
      final address = site?.address ?? 'Site address unavailable';
      final expected = 'Edited wording\nSite: $address';
      await pumpUntilCondition(
        tester,
        () => tester
            .widgetList<RichText>(find.byType(RichText))
            .any((widget) => widget.text.toPlainText().contains(expected)),
        'resolved site address in preview',
      );
      await tester.tap(find.text('Select'));
      await pumpUntilCondition(
        tester,
        () => result != null,
        'selected message',
      );
      expect(result!.getFormattedMessage(), expected);
      expect(result!.getFormattedMessage(), isNot(contains('{{')));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}

class _FixedSiteContext extends SourceContext {
  _FixedSiteContext(Site? site) : super(site: site);

  @override
  Future<void> resolveEntities() async {}
}

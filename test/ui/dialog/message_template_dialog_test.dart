@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_message_template.dart';
import 'package:hmb/entity/message_template.dart';
import 'package:hmb/ui/dialog/message_template_dialog.dart';
import 'package:hmb/ui/dialog/source_context.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';

import '../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  Future<void> settleAsync(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('selected SMS template immediately replaces editor text', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await DaoMessageTemplate().insert(
        MessageTemplate.forInsert(
          title: 'Feedback test template',
          message: 'Please leave feedback',
          messageType: MessageType.sms,
        ),
      );
      await DaoMessageTemplate().insert(
        MessageTemplate.forInsert(
          title: 'Appointment test template',
          message: 'Your appointment is tomorrow',
          messageType: MessageType.sms,
        ),
      );
      await DaoMessageTemplate().insert(
        MessageTemplate.forInsert(
          title: 'Email-only test template',
          message: 'Email body',
          messageType: MessageType.email,
        ),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MessageTemplateDialog(
          sourceContext: SourceContext(),
          messageType: MessageType.sms,
        ),
      ),
    );
    await settleAsync(tester);

    await tester.tap(find.byType(HMBDroplist<MessageTemplate>));
    await settleAsync(tester);

    expect(find.text('Email-only test template'), findsNothing);
    await tester.tap(find.text('Feedback test template'));
    await settleAsync(tester);

    var editor = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(editor.controller?.text, 'Please leave feedback');

    await tester.tap(find.text('Feedback test template'));
    await settleAsync(tester);
    await tester.tap(find.text('Appointment test template'));
    await tester.pump();

    editor = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(editor.controller?.text, 'Your appointment is tomorrow');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

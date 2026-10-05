@Tags(['flutter'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.dart';
import 'package:hmb/dao/dao_message_template.dart';
import 'package:hmb/entity/message_template.dart';
import 'package:hmb/ui/dialog/message_template_dialog.dart';
import 'package:hmb/ui/dialog/source_context.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:material_ui/material_ui.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

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

  testWidgets('template controls wait for asynchronous initialization', (
    tester,
  ) async {
    final ready = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: MessageTemplateDialog(
          sourceContext: _DelayedSourceContext(ready.future),
          messageType: MessageType.sms,
        ),
      ),
    );
    expect(find.byType(HMBDroplist<MessageTemplate>), findsNothing);
    expect(find.text('Select'), findsNothing);
    ready.complete();
    await pumpUntilFound(tester, find.text('Choose a template'));
    expect(find.byType(HMBDroplist<MessageTemplate>), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

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

    final accessed = <int>{};
    final originalNotifier = Dao.notifier;
    Dao.notifier = (dao, [id]) {
      originalNotifier(dao, id);
      if (dao is DaoMessageTemplate && id != null) {
        accessed.add(id);
      }
    };
    addTearDown(() => Dao.notifier = originalNotifier);

    await tester.pumpWidget(
      MaterialApp(
        home: MessageTemplateDialog(
          sourceContext: SourceContext(),
          messageType: MessageType.sms,
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Choose a template'));

    await tester.tap(find.byType(HMBDroplist<MessageTemplate>));
    await pumpUntilFound(tester, find.text('Feedback test template'));

    expect(find.text('Email-only test template'), findsNothing);
    await tester.tap(find.text('Feedback test template'));
    await settleAsync(tester);

    var editor = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Edit Message'),
    );
    expect(
      editor.controller?.text,
      'Please leave feedback\n\nSite: {{site.address}}',
    );

    await tester.tap(find.text('Feedback test template'));
    await pumpUntilFound(tester, find.text('Appointment test template'));
    await tester.tap(find.text('Appointment test template'));
    await tester.pump();

    editor = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Edit Message'),
    );
    expect(
      editor.controller?.text,
      'Your appointment is tomorrow\n\nSite: {{site.address}}',
    );

    // Selection returns immediately; recency is recorded in the background.
    await pumpUntilCondition(
      tester,
      () => accessed.length == 2,
      'both selected templates to finish recording access',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

class _DelayedSourceContext extends SourceContext {
  final Future<void> ready;
  _DelayedSourceContext(this.ready);

  @override
  Future<void> resolveEntities() async {
    await ready;
    await super.resolveEntities();
  }
}

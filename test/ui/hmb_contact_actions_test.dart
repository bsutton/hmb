@Tags(['flutter'])
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/contact.dart';
import 'package:hmb/ui/dialog/source_context.dart';
import 'package:hmb/ui/widgets/hmb_contact_actions.dart';
import 'package:hmb/ui/widgets/icons/hmb_phone_icon.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';

void main() {
  Contact contact({
    String phone = '0400000000',
    String email = 'a@example.com',
  }) => Contact.forInsert(
    firstName: 'Alex',
    surname: 'Example',
    mobileNumber: phone,
    officeNumber: '',
    landLine: '',
    emailAddress: email,
  );

  testWidgets('party actions copy values and offer call or text', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final party = contact();
    final source = SourceContext(contact: party);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ToastificationWrapper(
        child: MaterialApp(
          home: Scaffold(body: HMBContactActions(sourceContext: source)),
        ),
      ),
    );
    expect(
      tester
          .widget<HMBPhoneIcon>(find.byType(HMBPhoneIcon))
          .sourceContext
          .contact,
      same(party),
    );
    expect(find.byTooltip('Send an Email'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy Phone No. to the Clipboard'));
    await tester.pump();
    await tester.tap(find.byTooltip('Copy Email address to the Clipboard'));
    await tester.pump();
    expect(copied, ['0400000000', 'a@example.com']);
    await tester.tap(find.byTooltip('Call or Text'));
    await tester.pumpAndSettle();
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    // Let the shared clipboard notifications expire before disposing the app.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('missing contact details have no communication actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HMBContactActions(
            sourceContext: SourceContext(
              contact: contact(phone: ' ', email: ''),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(IconButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

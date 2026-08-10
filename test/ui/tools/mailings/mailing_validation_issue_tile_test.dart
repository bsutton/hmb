@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/tools/mailings/google_maps_route_service.dart';
import 'package:hmb/ui/tools/mailings/mailing_edit_screen.dart';
import 'package:hmb/ui/widgets/hmb_button.dart';

void main() {
  testWidgets('validation actions use HMB buttons on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final recipient = MailingRecipient.forInsert(
      mailingId: 1,
      customerId: 2,
      contactId: 3,
      siteId: 4,
      contactName: 'Alex Example',
      customerName: 'Example Customer',
      siteName: 'Home',
      addressLine1: 'Main Road',
      addressLine2: '',
      suburb: 'Melbourne',
      state: 'VIC',
      postcode: '3000',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MailingAddressValidationIssueTile(
            issue: MailingAddressValidationIssue(
              recipient: recipient,
              message: 'Address needs attention.',
            ),
            onApplySuggestion: null,
            onEditManually: () async {},
            onExclude: () async {},
            onNoMail: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Alex Example'), findsOneWidget);
    expect(find.text('Edit Manually'), findsOneWidget);
    expect(find.text('Exclude'), findsOneWidget);
    expect(find.text('No Mail'), findsOneWidget);
    expect(find.byType(HMBButton), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}

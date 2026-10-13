@Tags(['flutter'])
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/dialog/message_template_dialog.dart';
import 'package:hmb/ui/dialog/send_notice_for_job_dialog.dart';
import 'package:hmb/ui/dialog/source_context.dart';
import 'package:hmb/ui/widgets/icons/hmb_phone_icon.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money2/money2.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

Contact contact(String name) => Contact.forInsert(
  firstName: name,
  surname: 'Example',
  mobileNumber: '0400000000',
  landLine: '',
  officeNumber: '',
  emailAddress: '',
);

Supplier supplier() => Supplier.forInsert(
  name: 'Example Supplies',
  businessNumber: null,
  description: null,
  bsb: null,
  accountNumber: null,
  service: null,
);

Future<Customer> customer([String name = 'Example Customer']) async {
  final entity = Customer.forInsert(
    name: name,
    description: '',
    disbarred: false,
    customerType: CustomerType.residential,
    hourlyRate: Money.fromInt(10000, isoCode: 'AUD'),
    billingContactId: null,
  );
  await DaoCustomer().insert(entity);
  return entity;
}

Future<Site> site(String address) async {
  final entity = Site.forInsert(
    addressLine1: address,
    addressLine2: '',
    suburb: '',
    state: '',
    postcode: '',
    accessDetails: null,
  );
  await DaoSite().insert(entity);
  return entity;
}

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  Future<void> seed(String message) async {
    await testDb!.delete('message_template');
    await DaoMessageTemplate().insert(
      MessageTemplate.forInsert(
        title: 'Test template',
        message: message,
        messageType: MessageType.sms,
      ),
    );
  }

  final editor = find.widgetWithText(TextFormField, 'Edit Message');

  Future<void> compose(WidgetTester tester, SourceContext context) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HMBPhoneIcon('0400000000', sourceContext: context),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Call or Text'));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.text('Cancel')).dx,
      lessThan(tester.getCenter(find.text('Call')).dx),
    );
    await tester.tap(find.text('Text'));
    await pumpUntilFound(tester, editor);
    await tester.pumpAndSettle();
  }

  List<Uri> mockTransport(WidgetTester tester) {
    final launched = <Uri>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'launch') {
        launched.add(Uri.parse((call.arguments as Map)['url'] as String));
      }
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    return launched;
  }

  for (final kind in ['supplier', 'contact', 'customer']) {
    testWidgets('$kind without site sends an edited independent template', (
      tester,
    ) async {
      late SourceContext context;
      await tester.runAsync(() async {
        await seed('Hello {{recipient.name}}, thank you');
        context = switch (kind) {
          'supplier' => SourceContext(
            supplier: supplier(),
            contact: contact('Sam'),
          ),
          'contact' => SourceContext(contact: contact('Alex')),
          _ => SourceContext(customer: await customer()),
        };
      });
      final launched = mockTransport(tester);
      await compose(tester, context);
      expect(find.byType(HMBDroplist<Site>), findsNothing);
      expect(
        tester.widget<TextFormField>(editor).controller!.text,
        'Hello {{recipient.name}}, thank you',
      );
      await tester.enterText(editor, 'Hello {{recipient.name}}, draft edited');
      await tester.pump();
      await tester.tap(find.text('Select'));
      await pumpUntilCondition(tester, () => launched.isNotEmpty, 'mock SMS');
      expect(launched.single.path, '0400000000');
      expect(
        launched.single.queryParameters['body'],
        'Hello ${context.recipientName}, draft edited',
      );
      expect(context.site, isNull);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('missing site and custom fields are editable and block handoff', (
    tester,
  ) async {
    await tester.runAsync(
      () => seed('At {{site.address}} bring {{part}} for {{reference}}'),
    );
    final launched = mockTransport(tester);
    await compose(tester, SourceContext(supplier: supplier()));
    expect(find.byType(HMBDroplist<Site>), findsNothing);
    await tester.tap(find.text('Select'));
    await pumpUntilFound(tester, find.byKey(const Key('template-error')));
    expect(
      find.text('Complete or remove: site.address, part, reference'),
      findsOneWidget,
    );
    expect(launched, isEmpty);
    for (final entry in {
      'site.address': 'Delivery entrance',
      'part': 'hinges',
      'reference': 'PO123',
    }.entries) {
      final field = find.widgetWithText(TextFormField, entry.key);
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    await tester.tap(find.text('Select'));
    await pumpUntilCondition(tester, () => launched.isNotEmpty, 'filled SMS');
    expect(
      launched.single.queryParameters['body'],
      'At Delivery entrance bring hinges for PO123',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('legacy site line can be removed without selecting a fake site', (
    tester,
  ) async {
    await tester.runAsync(() => seed('Thank you\n\nSite: {{site.address}}'));
    final launched = mockTransport(tester);
    await compose(tester, SourceContext(supplier: supplier()));
    await tester.enterText(editor, 'Thank you');
    await tester.pump();
    await tester.tap(find.text('Select'));
    await pumpUntilCondition(tester, () => launched.isNotEmpty, 'edited SMS');
    expect(launched.single.queryParameters['body'], 'Thank you');
    await tester.pumpAndSettle();
  });

  testWidgets('multiple sites require selection and cancel/back discard it', (
    tester,
  ) async {
    late SourceContext context;
    await tester.runAsync(() async {
      await seed('Meet at {{site.address}}');
      final owner = await customer();
      await DaoSiteCustomer().insertJoin(await site('1 First Street'), owner);
      await DaoSiteCustomer().insertJoin(await site('2 Second Street'), owner);
      context = SourceContext(customer: owner);
    });
    final launched = mockTransport(tester);
    for (final cancel in [true, false]) {
      await compose(tester, context);
      await tester.tap(find.text('Select'));
      await pumpUntilFound(tester, find.byKey(const Key('template-error')));
      expect(launched, isEmpty);
      await tester.tap(find.byType(HMBDroplist<Site>));
      await pumpUntilFound(tester, find.text('2 Second Street'));
      await tester.tap(find.text('2 Second Street'));
      await tester.pumpAndSettle();
      if (cancel) {
        await tester.tap(find.text('Cancel'));
      } else {
        await tester.pageBack();
      }
      await tester.pumpAndSettle();
      expect(context.site, isNull);
      expect(launched, isEmpty);
    }
    await compose(tester, context);
    await tester.tap(find.byType(HMBDroplist<Site>));
    await pumpUntilFound(tester, find.text('1 First Street'));
    await tester.tap(find.text('1 First Street'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await pumpUntilCondition(tester, () => launched.isNotEmpty, 'chosen site');
    expect(launched.single.queryParameters['body'], 'Meet at 1 First Street');
    expect(context.site, isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('known job address and recipient do not leak into next draft', (
    tester,
  ) async {
    late SourceContext context;
    await tester.runAsync(() async {
      await seed('Hello {{customer.name}}');
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(10000, isoCode: 'AUD'),
      );
      context = SourceContext(job: job);
    });
    final launched = mockTransport(tester);
    await compose(tester, context);
    expect(
      tester.widget<TextFormField>(editor).controller!.text,
      'Hello {{customer.name}}\n\nSite: {{site.address}}',
    );
    expect(find.byType(HMBDroplist<Customer>), findsNothing);
    await tester.tap(find.text('Select'));
    await pumpUntilCondition(tester, () => launched.isNotEmpty, 'job SMS');
    expect(launched.single.queryParameters['body'], contains('Hello Pat'));
    expect(launched.single.queryParameters['body'], contains('1 Test St'));
    await tester.pumpAndSettle();
    await compose(tester, SourceContext(supplier: supplier()));
    expect(find.byType(HMBDroplist<Site>), findsNothing);
    await tester.tap(find.text('Select'));
    await pumpUntilFound(tester, find.byKey(const Key('template-error')));
    expect(launched, hasLength(1));
    expect(find.text('Complete or remove: customer.name'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  test(
    'saving a site-independent SMS does not insert a site requirement',
    () async {
      await seed('Thanks {{recipient.name}}');
      expect(
        (await DaoMessageTemplate().getByFilter(null)).single.message,
        'Thanks {{recipient.name}}',
      );
    },
  );

  test(
    'contact shared by customers never infers their sites or names',
    () async {
      final person = contact('Shared');
      await DaoContact().insert(person);
      final first = await customer();
      final second = await customer('Second Customer');
      for (final owner in [first, second]) {
        await testDb!.insert('customer_contact', {
          'customer_id': owner.id,
          'contact_id': person.id,
        });
        await DaoSiteCustomer().insertJoin(await site('Owner property'), owner);
      }
      final context = SourceContext(contact: person);
      await context.resolveEntities();
      expect(context.customer, isNull);
      expect(context.site, isNull);
      expect(context.recipientName, 'Shared');
      final supplierContext = SourceContext(
        supplier: supplier(),
        contact: person,
      );
      await supplierContext.resolveEntities();
      expect(supplierContext.customer, isNull);
      expect(supplierContext.site, isNull);
    },
  );

  testWidgets('small screen and enlarged text can edit and cancel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() => seed('Thanks'));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: MessageTemplateDialog(sourceContext: SourceContext()),
      ),
    );
    await pumpUntilFound(tester, editor);
    await tester.enterText(editor, 'Edited thanks');
    await tester.pump();
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'built-in blank draft keeps signature without legacy site suffix',
    (tester) async {
      await tester.runAsync(() async {
        await testDb!.delete('message_template');
        await DaoMessageTemplate().insert(
          MessageTemplate.forInsert(
            title: 'Blank',
            message: '\n\n{{signature}}\n\nSite: {{site.address}}',
            messageType: MessageType.sms,
            owner: MessageTemplateOwner.system,
          ),
        );
      });
      await compose(tester, SourceContext(supplier: supplier()));
      expect(
        tester.widget<TextFormField>(editor).controller!.text,
        '\n\n{{signature}}',
      );
      expect(find.byType(HMBDroplist<Site>), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );

  test('formatter rejects missing, malformed and nested placeholders', () {
    for (final message in ['{{unknown}}', '{{unfinished', '{{value}}']) {
      final result = SelectedMessageTemplate(
        template: MessageTemplate.forInsert(
          title: 'test',
          message: message,
          messageType: MessageType.sms,
        ),
        values: {'value': '{{nested}}'},
      );
      expect(result.missingValues, isNotEmpty);
      expect(result.getFormattedMessage, throwsStateError);
    }
  });

  test('schedule templates match the selected mobile only', () {
    final primary = contact('Primary');
    final other = contact('Other').copyWith(mobileNumber: '0400000001');
    expect(
      noticeTemplateContact([primary, other], ['0400 000 001']),
      same(other),
    );
    expect(noticeTemplateContact([primary, other], ['0400000002']), isNull);
    expect(
      noticeTemplateContact([primary, other], ['0400000000', '0400000001']),
      isNull,
    );
    expect(noticeTemplateContact([primary, primary], ['0400000000']), isNull);
  });
}

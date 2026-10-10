@Tags(['flutter'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_customer.dart';
import 'package:hmb/dao/dao_message_template.dart';
import 'package:hmb/dao/dao_site.dart';
import 'package:hmb/dao/dao_site_customer.dart';
import 'package:hmb/entity/customer.dart';
import 'package:hmb/entity/job.dart';
import 'package:hmb/entity/job_activity.dart';
import 'package:hmb/entity/job_status.dart';
import 'package:hmb/entity/message_template.dart';
import 'package:hmb/entity/site.dart';
import 'package:hmb/ui/dialog/message_placeholders/noop_source.dart';
import 'package:hmb/ui/dialog/message_placeholders/site_holder.dart';
import 'package:hmb/ui/dialog/message_placeholders/site_source.dart';
import 'package:hmb/ui/dialog/message_template_dialog.dart';
import 'package:hmb/ui/dialog/send_notice_for_job_dialog.dart';
import 'package:hmb/ui/dialog/source_context.dart';
import 'package:money2/money2.dart';

import '../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  Future<Site> makeSite(String address) async {
    final site = Site.forInsert(
      addressLine1: address,
      addressLine2: '',
      suburb: '',
      state: '',
      postcode: '',
      accessDetails: null,
    );
    await DaoSite().insert(site);
    return site;
  }

  Future<Customer> makeCustomer() async {
    final customer = Customer.forInsert(
      name: 'SMS regression customer',
      description: '',
      disbarred: false,
      customerType: CustomerType.residential,
      hourlyRate: Money.fromInt(10000, isoCode: 'AUD'),
      billingContactId: null,
    );
    await DaoCustomer().insert(customer);
    return customer;
  }

  Job makeJob(Customer customer, int? siteId) => Job.forInsert(
    customerId: customer.id,
    summary: 'Repairs',
    description: '',
    siteId: siteId,
    contactId: null,
    status: JobStatus.values.first,
    hourlyRate: null,
    bookingFee: null,
    billingContactId: null,
  );

  test(
    'every stored SMS has a site field and formats without duplicates',
    () async {
      final templates = await DaoMessageTemplate().getByFilter(null);
      final sms = templates.where((t) => t.messageType == MessageType.sms);
      expect(sms, isNotEmpty);
      for (final template in sms) {
        expect(
          template.message,
          contains('{{site.address}}'),
          reason: template.title,
        );
        final values = {
          for (final name in extractMessagePlaceholderNames(template.message))
            name: name == 'site.address' ? '22 Work Street' : 'Example',
        };
        final formatted = SelectedMessageTemplate(
          template: template,
          values: values,
        ).getFormattedMessage();
        expect(formatted, contains('22 Work Street'), reason: template.title);
        expect(formatted, isNot(contains('{{')), reason: template.title);
        expect(template.messageWithSiteAddress, template.message);
      }
    },
  );

  test(
    'migration preserves custom text, email, metadata and existing fields',
    () async {
      final fixture = File(
        'test/sql/message_template_site_address.sql',
      ).readAsStringSync();
      for (final statement in fixture.split(';')) {
        if (statement.trim().isNotEmpty) {
          await testDb!.execute(statement);
        }
      }
      final sql = File(
        'assets/sql/upgrade_scripts/v225.sql',
      ).readAsStringSync();
      await testDb!.execute(sql);
      await testDb!.execute(sql);
      final rows = await testDb!.query(
        'message_template',
        where: "title LIKE '654 %'",
        orderBy: 'title',
      );
      expect(rows[0]['message'], 'Custom wording\n\nSite: {{site.address}}');
      expect(rows[0]['enabled'], 0);
      expect(rows[0]['ordinal'], 42);
      expect(rows[1]['message'], 'Email wording');
      expect(rows[2]['message'], 'Meet at {{site.address}} please');
      expect(
        rows[3]['message'],
        'My customised system wording\n\nSite: {{site.address}}',
      );
    },
  );

  test(
    'job site overrides billing/first site and stale supplied site',
    () async {
      final customer = await makeCustomer();
      final billing = await makeSite('1 Billing Road');
      final work = await makeSite('22 Work Street');
      await DaoSiteCustomer().insertJoin(billing, customer);
      await DaoSiteCustomer().insertJoin(work, customer);
      await DaoSiteCustomer().setAsPrimary(billing, customer);
      final context = SourceContext(
        customer: customer,
        job: makeJob(customer, work.id),
        site: billing,
      );
      await context.resolveEntities();
      expect(context.site?.id, work.id);
      final source = SiteSource()..dependencyChanged(NoopSource(), context);
      expect(await SiteHolder(siteSource: source).value(), '22 Work Street');
      context.job = makeJob(customer, billing.id);
      await context.resolveSite();
      source.dependencyChanged(NoopSource(), context);
      expect(await SiteHolder(siteSource: source).value(), '1 Billing Road');
    },
  );

  test('missing job site never falls back to customer property', () async {
    final customer = await makeCustomer();
    final billing = await makeSite('1 Billing Road');
    await DaoSiteCustomer().insertJoin(billing, customer);
    for (final siteId in [null, 999999]) {
      final context = SourceContext(
        customer: customer,
        job: makeJob(customer, siteId),
        site: billing,
      );
      await context.resolveEntities();
      expect(context.site, isNull);
      final source = SiteSource()..dependencyChanged(NoopSource(), context);
      expect(
        await SiteHolder(siteSource: source).value(),
        'Site address unavailable',
      );
    }
  });

  test(
    'customer-only context infers only a single site, honours explicit site',
    () async {
      final customer = await makeCustomer();
      final first = await makeSite('1 First Street');
      final second = await makeSite('2 Second Street');
      final none = SourceContext(customer: customer);
      await none.resolveEntities();
      expect(none.site, isNull);
      await DaoSiteCustomer().insertJoin(first, customer);
      final single = SourceContext(customer: customer);
      await single.resolveEntities();
      expect(single.site?.id, first.id);
      await DaoSiteCustomer().insertJoin(second, customer);
      final multiple = SourceContext(customer: customer);
      await multiple.resolveEntities();
      expect(multiple.site, isNull);
      final explicit = SourceContext(customer: customer, site: second);
      await explicit.resolveEntities();
      expect(explicit.site?.id, second.id);
    },
  );

  test('blank and partial site addresses have sensible text', () async {
    final blank = await makeSite('   ');
    final source = SiteSource()..site = blank;
    expect(
      await SiteHolder(siteSource: source).value(),
      'Site address unavailable',
    );
    source.site = blank.copyWith(suburb: 'Richmond', postcode: '3121');
    expect(await SiteHolder(siteSource: source).value(), 'Richmond, 3121');
  });

  test('all booking statuses include the actual site address', () async {
    final site = await makeSite('22 Work Street');
    for (final status in JobActivityStatus.values) {
      final message = noticeSmsBodyForActivity(
        activity: JobActivity.forInsert(
          jobId: 1,
          start: DateTime(2026, 10, 5, 9),
          end: DateTime(2026, 10, 5, 10),
        ).copyWith(status: status),
        contact: null,
        businessName: 'Example Business',
        site: site,
      );
      expect(message, contains('\nSite: 22 Work Street\n'));
      expect(message, isNot(contains('{{')));
    }
  });
}

@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/contact.dart';
import 'package:hmb/entity/job_activity.dart';
import 'package:hmb/ui/dialog/send_notice_for_job_dialog.dart';

void main() {
  group('scheduled job notice greetings', () {
    test('uses the contact full name in the email greeting', () {
      final contact = Contact.forInsert(
        firstName: 'Ada',
        surname: 'Lovelace',
        mobileNumber: '0400000000',
        landLine: '',
        officeNumber: '',
        emailAddress: 'ada@example.com',
      );

      expect(noticeEmailGreetingForContact(contact), 'Ada Lovelace,');
    });

    test('uses the contact full name in the SMS greeting', () {
      final contact = Contact.forInsert(
        firstName: 'Ada',
        surname: 'Lovelace',
        mobileNumber: '0400000000',
        landLine: '',
        officeNumber: '',
        emailAddress: 'ada@example.com',
      );

      expect(noticeSmsGreetingForContact(contact), 'Hi Ada Lovelace,');
    });

    test('falls back when there is no contact name', () {
      expect(noticeEmailGreetingForContact(null), 'Hello,');
      expect(noticeSmsGreetingForContact(null), 'Hi,');
    });
  });

  group('scheduled job SMS body', () {
    final contact = Contact.forInsert(
      firstName: 'Ada',
      surname: 'Lovelace',
      mobileNumber: '0400000000',
      landLine: '',
      officeNumber: '',
      emailAddress: 'ada@example.com',
    );
    final activity = JobActivity.forInsert(
      jobId: 1,
      start: DateTime(2026, 3, 5, 9, 5),
      end: DateTime(2026, 3, 5, 10, 30),
    );

    test('new proposed event asks if the time works with personalization', () {
      expect(
        noticeSmsBodyForActivity(
          activity: activity,
          contact: contact,
          businessName: 'Test Business',
        ),
        'Hi Ada Lovelace, would 2026-03-05 at 09:05 – 10:30 work for you?'
        '\nSite address unavailable\nTest Business',
      );
    });

    test('edited event uses its current status and date/time', () {
      final confirmed = activity.copyWith(status: JobActivityStatus.confirmed);
      final edited = confirmed.copyWith(
        status: JobActivityStatus.proposed,
        start: DateTime(2026, 4, 6, 14, 15),
        end: DateTime(2026, 4, 6, 16),
      );
      expect(
        noticeSmsBodyForActivity(
          activity: edited,
          contact: null,
          businessName: 'Test Business',
        ),
        'Hi, would 2026-04-06 at 14:15 – 16:00 work for you?'
        '\nSite address unavailable\nTest Business',
      );
    });

    for (final status in [
      JobActivityStatus.confirmed,
      JobActivityStatus.tentative,
    ]) {
      test('preserves existing wording for ${status.name} events', () {
        expect(
          noticeSmsBodyForActivity(
            activity: activity.copyWith(status: status),
            contact: contact,
            businessName: 'Test Business',
          ),
          'Hi Ada Lovelace, your job is scheduled. '
          'Date: 2026-03-05, Time: 09:05 – 10:30'
          '\nSite address unavailable\nTest Business',
        );
      });
    }
  });
}

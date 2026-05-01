import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/contact.dart';
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
}

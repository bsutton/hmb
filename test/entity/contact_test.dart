import 'package:hmb/entity/contact.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith can clear alternate email', () {
    final contact = Contact.forInsert(
      firstName: 'Pat',
      surname: 'Tester',
      mobileNumber: '',
      landLine: '',
      officeNumber: '',
      emailAddress: 'pat@example.com',
      alternateEmail: 'other@example.com',
    );

    final updated = contact.copyWith(clearAlternateEmail: true);

    expect(updated.alternateEmail, isNull);
  });
}

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

  test('role description is copied and persisted in maps', () {
    final contact = Contact.forInsert(
      firstName: 'Pat',
      surname: 'Tester',
      mobileNumber: '',
      landLine: '',
      officeNumber: '',
      emailAddress: 'pat@example.com',
      roleDescription: 'Property manager',
    );

    final updated = contact.copyWith(roleDescription: 'Site manager');

    expect(updated.roleDescription, 'Site manager');
    expect(updated.toMap()['role_description'], 'Site manager');
  });
}

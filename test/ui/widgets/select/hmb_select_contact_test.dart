import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/widgets/select/hmb_select_contact.dart';
import 'package:test/test.dart';

void main() {
  test('contact selection includes the role when requested', () {
    final contact = Contact.forInsert(
      firstName: 'Alex',
      surname: 'Smith',
      mobileNumber: '',
      landLine: '',
      officeNumber: '',
      emailAddress: 'alex@example.com',
      roleDescription: 'Body corporate manager',
    );

    expect(
      formatContactForSelection(contact, showRole: true),
      'Alex Smith — Body corporate manager',
    );
    expect(formatContactForSelection(contact), 'Alex Smith');
  });
}

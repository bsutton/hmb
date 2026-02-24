import 'package:hmb/entity/contact.dart';
import 'package:hmb/entity/customer.dart';
import 'package:hmb/ui/dialog/message_placeholders/contact_source.dart';
import 'package:hmb/ui/dialog/message_placeholders/customer_name.dart';
import 'package:hmb/ui/dialog/message_placeholders/customer_source.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

void main() {
  group('CustomerName placeholder', () {
    test('prefers contact first name when available', () async {
      final customerSource = CustomerSource();
      final contactSource = ContactSource();
      customerSource.customer = Customer.forInsert(
        name: 'Acme Pty Ltd',
        description: '',
        disbarred: false,
        customerType: CustomerType.residential,
        hourlyRate: Money.fromInt(10000, isoCode: 'AUD'),
        billingContactId: null,
      );
      contactSource.contact = Contact.forInsert(
        firstName: 'Sam',
        surname: 'Builder',
        mobileNumber: '',
        landLine: '',
        officeNumber: '',
        emailAddress: 'sam@example.com',
      );

      final placeholder = CustomerName(
        customerSource: customerSource,
        contactSource: contactSource,
      );

      expect(await placeholder.value(), 'Sam');
    });

    test('falls back to customer name when contact is missing', () async {
      final customerSource = CustomerSource()
      ..customer = Customer.forInsert(
        name: 'Acme Pty Ltd',
        description: '',
        disbarred: false,
        customerType: CustomerType.residential,
        hourlyRate: Money.fromInt(10000, isoCode: 'AUD'),
        billingContactId: null,
      );

      final placeholder = CustomerName(customerSource: customerSource);

      expect(await placeholder.value(), 'Acme Pty Ltd');
    });
  });
}

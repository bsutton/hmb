import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/tools/mailings/google_maps_route_service.dart';
import 'package:hmb/ui/tools/mailings/mailing_edit_screen.dart';

void main() {
  test('a successfully validated edited recipient is selected', () {
    final recipient = _recipient();

    final updated = recipientAfterAddressValidation(recipient, const []);

    expect(updated.selected, isTrue);
  });

  test('an edited recipient with a validation issue remains unselected', () {
    final recipient = _recipient().copyWith(selected: true);

    final updated = recipientAfterAddressValidation(recipient, [
      MailingAddressValidationIssue(message: 'Still invalid'),
    ]);

    expect(updated.selected, isFalse);
  });
}

MailingRecipient _recipient() => MailingRecipient.forInsert(
  mailingId: 1,
  customerId: 2,
  contactId: 3,
  siteId: 4,
  contactName: 'Alex Example',
  customerName: 'Example Customer',
  siteName: 'Home',
  addressLine1: '1 Main Road',
  addressLine2: '',
  suburb: 'Melbourne',
  state: 'VIC',
  postcode: '3000',
  selected: false,
);

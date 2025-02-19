import 'package:strings/strings.dart';

import '../../../entity/contact.dart';
import '../../../util/exceptions.dart';

class XeroContact {
  XeroContact({required this.name, required this.email, required this.phone}) {
    if (Strings.isBlank(name) || Strings.isBlank(email)) {
      throw XeroException(
        'You must provide a valid name and email for a xero contact',
      );
    }
  }

  /// Create a [XeroContact] from a [Contact].
  factory XeroContact.fromContact(Contact contact) => XeroContact(
    name: contact.fullname,
    email: contact.emailAddress,
    phone: contact.bestPhone,
  );

  final String name;
  final String email;
  final String phone;

  Map<String, dynamic> toJson() {
    if (Strings.isNotBlank(phone)) {
      return {
            'Name': name,
            'EmailAddress': email,
            'Phones': [
              {'PhoneType': 'MOBILE', 'PhoneNumber': phone},
            ],
          }
          as Map<String, dynamic>;
    } else {
      return {'Name': name, 'EmailAddress': email} as Map<String, dynamic>;
    }
  }
}

// {
//           'Name': contact.fullname,
//           'FirstName': contact.firstName,
//           'LastName': contact.surname,
//           'EmailAddress': contact.emailAddress,
//           'Addresses': [
//             {
//               'AddressType': 'POBOX',
//               'AddressLine1': site?.addressLine1,
//               'City': site?.suburb,
//               'Region': site?.state,
//               'PostalCode': site?.postcode,
//               // 'Country': site?.country
//             }
//           ],
//           'Phones': [
//             {'PhoneType': 'DEFAULT', 'PhoneNumber': contact.bestPhone}
//           ]
//         }

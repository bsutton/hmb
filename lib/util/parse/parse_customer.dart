// {
// HMBToast.info(
//   'Unable to extract any customer details from the message. You can copy and paste the details manually.',
// );

import 'package:strings/strings.dart';

import '../../dao/dao.g.dart';
import 'parse.dart';
import 'parse_address.dart';

class ParsedCustomer {
  ParsedCustomer({
    required this.customerName,
    required this.email,
    required this.firstname,
    required this.surname,
    required this.mobile,
    required this.address,
  });

  static Future<ParsedCustomer> parse(String text) async {
    final system = await DaoSystem().get();
    final userFirstname = system.firstname ?? '';
    final userSurname = system.surname ?? '';
    final email = parseEmail(text);
    final mobile = parsePhone(text);
    final address = ParsedAddress.parse(text);

    final nameRegex = RegExp(r'\b([A-Z][a-z]+)\s+([A-Z][a-z]+)\b');
    final matches = nameRegex.allMatches(text);

    var firstName = '';
    var lastName = '';

    for (final match in matches) {
      final candidateFirst = match.group(1) ?? '';
      final candidateLast = match.group(2) ?? '';

      final isRecipientName =
          candidateFirst.toLowerCase() == userFirstname.toLowerCase() ||
          candidateFirst.toLowerCase() == userSurname.toLowerCase() ||
          candidateLast.toLowerCase() == userFirstname.toLowerCase() ||
          candidateLast.toLowerCase() == userSurname.toLowerCase();

      if (!isRecipientName) {
        firstName = candidateFirst;
        lastName = candidateLast;
        break;
      }
    }

    final customerName = '$firstName $lastName'.trim();

    return ParsedCustomer(
      customerName: customerName,
      email: email,
      mobile: mobile,
      firstname: firstName,
      surname: lastName,
      address: address,
    );
  }

  String customerName;
  String email;
  String mobile;
  String firstname;
  String surname;
  ParsedAddress address;

  bool isEmpty() =>
      Strings.isBlank(firstname) &&
      Strings.isBlank(surname) &&
      Strings.isBlank(email) &&
      Strings.isBlank(mobile) &&
      Strings.isBlank(customerName) &&
      address.isEmpty();
}

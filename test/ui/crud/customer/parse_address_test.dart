import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/util/dart/parse/parse_address.dart';

void main() {
  testWidgets('parse address ...', (tester) async {
    const message = '''
Hi Brett. I think 3 new skirting boards are some plastering. 
It's Barbara Uren. 4/3 kenilworth parade Ivanhoe. 
barb.uren@gmail.com''';
    final address = ParsedAddress.parse(message);

    expect(address.street, equals('4/3 kenilworth parade'));
    expect(address.city, equals('Ivanhoe'));
  });

  testWidgets('parse address without suffix but with comma', (tester) async {
    const message = '''
Could you please provide me with a quote to provide and install a handrail at 95 The Righi, Eaglemont. The handrail is required for the steps from the driveway up to the front verandah.
''';
    final address = ParsedAddress.parse(message);

    expect(address.street, equals('95 The Righi'));
    expect(address.city, equals('Eaglemont'));
  });
}

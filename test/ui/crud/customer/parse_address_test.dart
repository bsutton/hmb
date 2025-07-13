import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/crud/customer/parse_address.dart';

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
}

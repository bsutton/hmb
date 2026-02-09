import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_system.dart';
import 'package:hmb/util/dart/parse/parse_customer.dart';

import '../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();

    final system = await DaoSystem().get();

    system
      ..firstname = 'Brett'
      ..surname = 'Sutton';

    await DaoSystem().update(system);
  });

  test('Jan Twain ...', () async {
    const message = '''
Hi Brett. I think 3 new skirting boards are some plastering. 
It's Jan Twain. 14/3 kennedy Rd Ivanhoe. 
jan.twain@gmail.com''';

    final parsed = await ParsedCustomer.parse(message);

    expect(parsed.customerName, equals('Jan Twain'));
    expect(parsed.firstname, equals('Jan'));
    expect(parsed.surname, equals('Twain'));
    expect(parsed.email, equals('jan.twain@gmail.com'));
    final address = parsed.address;
    expect(address.street, equals('14/3 kennedy Rd'));
    expect(address.city, equals('Ivanhoe'));
    expect(address.state, equals(''));
    expect(address.postalCode, equals(''));
  });

  test('john Smith', () async {
    const message = '''
Hi Brett 
Just following up with my details 
Address 20 Nailston Lane Ivanhoe (off Smith Road)
Phone 0417 999 999
Kind regards 
John Smith ''';

    final parsed = await ParsedCustomer.parse(message);

    expect(parsed.customerName, equals('John Smith'));
    expect(parsed.firstname, equals('John'));
    expect(parsed.surname, equals('Smith'));
    expect(parsed.mobile, equals('0417999999'));
    final address = parsed.address;
    expect(address.street, equals('20 Nailston Lane'));
    expect(address.city, equals('Ivanhoe'));
    expect(address.state, equals(''));
    expect(address.postalCode, equals(''));
  });

  test('margaret huges', () async {
    const message = '''
Brett leaving tomorrow for Perth for 3 weeks. Can you postpone until I get back please.   Margaret Huges.    Job.   30 upper Heidelberg  road 
 ''';

    final parsed = await ParsedCustomer.parse(message);

    expect(parsed.customerName, equals('Margaret Huges'));
    expect(parsed.firstname, equals('Margaret'));
    expect(parsed.surname, equals('Huges'));
    expect(parsed.mobile, equals(''));
    final address = parsed.address;
    expect(address.street, equals('30 upper Heidelberg road'));
    expect(address.city, equals(''));
    expect(address.state, equals(''));
    expect(address.postalCode, equals(''));
  });

  test('Janice Thoms', () async {
    const message = '''
Janice Thoms 30 Upper Heidelberg road Ivanhoe.  Brett you booked me in for 1  on Friday. Doors
 ''';

    final parsed = await ParsedCustomer.parse(message);

    expect(parsed.customerName, equals('Janice Thoms'));
    expect(parsed.firstname, equals('Janice'));
    expect(parsed.surname, equals('Thoms'));
    expect(parsed.mobile, equals(''));
    final address = parsed.address;
    expect(address.street, equals('30 Upper Heidelberg road'));
    expect(address.city, equals('Ivanhoe'));
    expect(address.state, equals(''));
    expect(address.postalCode, equals(''));
  });

  test('Wilow', () async {
    const message = '''
Hi Wilow and Peter Bain.  We got your contact details from the Nextdoor app. 
 We live in Ivanhoe and have a number of small jobs which we would like to have 
 completed in the next few months ( by October at the latest). 
 The first is to complete the framing and plastering of a small window (~550 x1050) 
 including some external brickwork.  (We can supply the bricks and the internal window sill).  
If you are interested you can call Peter when you are free on 0429 999 999.   
We hope to hear from you soon.
 ''';

    final parsed = await ParsedCustomer.parse(message);

    expect(parsed.customerName, equals('Peter Bain'));
    expect(parsed.firstname, equals('Peter'));
    expect(parsed.surname, equals('Bain'));
    expect(parsed.mobile, equals('0429999999'));
    final address = parsed.address;
    expect(address.street, equals(''));
    expect(address.city, equals(''));
    expect(address.state, equals(''));
    expect(address.postalCode, equals(''));
  });

  test('Cain', () async {
    const message = '''
Hi Brett, thanks for speaking just now. 
Looking for your expert assistance with the front door and two internal doors 
that do not close properly. Address here is 22a Victor Street Ivanhoe. 
Any help appreciated as it is getting much more fun with a broken ankle! Cain

 ''';

    final parsed = await ParsedCustomer.parse(message);

    expect(parsed.customerName, equals(''));
    expect(parsed.firstname, equals(''));
    expect(parsed.surname, equals(''));
    expect(parsed.mobile, equals(''));
    final address = parsed.address;
    expect(address.street, equals('22a Victor Street'));
    expect(address.city, equals('Ivanhoe'));
    expect(address.state, equals(''));
    expect(address.postalCode, equals(''));
  });

  test('Able', () async {
    const message = '''
Subject: Handyman Serviced
Dear Brett:
My address is 

    42 Dog Avenue,   
    Balwyn North
    0431999999
   able.man@gmail.com
   Thanks, Bruce

 ''';

    final parsed = await ParsedCustomer.parse(message);

    expect(parsed.customerName, equals('Handyman Serviced'));
    expect(parsed.firstname, equals('Handyman'));
    expect(parsed.surname, equals('Serviced'));
    expect(parsed.mobile, equals('0431999999'));
    expect(parsed.email, equals('able.man@gmail.com'));
    final address = parsed.address;
    expect(address.street, equals('42 Dog Avenue'));
    expect(address.city, equals('Balwyn North'));
    expect(address.state, equals(''));
    expect(address.postalCode, equals(''));
  });
}

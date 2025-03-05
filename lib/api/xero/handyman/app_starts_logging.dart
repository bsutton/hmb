import 'dart:convert';
import 'dart:io';

import '../../../dao/dao_system.dart';
import '../../../src/version/version.g.dart';

/// Helper to obfuscate a business name by keeping the first character of each word
/// and replacing the rest with asterisks.
String obfuscateBusinessName(String name) => name
    .split(' ')
    .map((word) {
      if (word.length <= 1) {
        return word;
      }
      final stars = List.filled(word.length - 1, '*').join();
      return word[0] + stars;
    })
    .join(' ');

Future<void> logAppStartup() async {
  // Retrieve the system object.
  final daoSystem = DaoSystem();
  final system = await daoSystem.get();
  final businessName = system.businessName ?? 'Unknown';
  final obfuscatedBusinessName = obfuscateBusinessName(businessName);

  // Build the YAML message including the app version.
  final now = DateTime.now().toIso8601String();
  final message = '''
start: "$now"
business name: "$obfuscatedBusinessName"
app version: "$packageVersion"
''';
  final data = utf8.encode(message);

  // Determine the target host: use localhost in debug mode.
  // const targetHost = kDebugMode ? '127.0.0.1' : 'ivanhoehandyman.com.au';
  // const targetHost = 'ivanhoehandyman.com.au';

  const targetHost = '34.125.92.27';

  // Resolve the target host.
  final addresses = await InternetAddress.lookup(targetHost);
  if (addresses.isEmpty) {
    print('Could not resolve $targetHost');
    return;
  }
  final targetAddress = addresses.first;
  // The port must match the UDP server's port (e.g. 4040).
  const targetPort = 4040;

  // Bind a UDP socket on an available local port.
  final udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  udpSocket.send(data, targetAddress, targetPort);
  print('Sent UDP packet to ${targetAddress.address}:$targetPort');
  udpSocket.close();
}

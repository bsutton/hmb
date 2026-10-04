/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../dao/dao_system.dart';
import '../../../src/version/version.g.dart';

/// Helper to obfuscate a business name by keeping the first character of
///  each word
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
  if (kIsWeb) {
    // dart:io networking APIs are not supported on web.
    return;
  }
  try {
    final system = await DaoSystem().get();
    // This hostname must use a DNS-only AAAA record for UDP delivery.
    await sendAppStartupTelemetry(
      system.businessName ?? 'Unknown',
      targetHost: 'telemetry.ivanhoehandyman.com.au',
    );
  } catch (_) {
    // Telemetry must never prevent startup, including configuration failures.
  }
}

/// Sends best-effort app-start telemetry to the IPv6 collector.
///
/// Network operations are bounded independently. A bind completing after its
/// timeout still closes its socket, since Future.timeout does not cancel it.
Future<void> sendAppStartupTelemetry(
  String businessName, {
  required String targetHost,
  DateTime? startedAt,
  String? appVersion,
  Duration networkTimeout = const Duration(seconds: 2),
  Future<List<InternetAddress>> Function(
        String host, {
        InternetAddressType type,
      })
      lookup =
      InternetAddress.lookup,
  Future<RawDatagramSocket> Function(InternetAddress host, int port) bind =
      RawDatagramSocket.bind,
}) async {
  RawDatagramSocket? socket;
  var bindTimedOut = false;
  try {
    final obfuscatedBusinessName = obfuscateBusinessName(businessName);
    final now = (startedAt ?? DateTime.now()).toIso8601String();
    final message =
        '''
start: "$now"
business name: "$obfuscatedBusinessName"
app version: "${appVersion ?? packageVersion}"
''';
    final addresses = await lookup(
      targetHost,
      type: InternetAddressType.IPv6,
    ).timeout(networkTimeout);
    if (addresses.isEmpty) {
      return;
    }

    socket = await bind(InternetAddress.anyIPv6, 0)
        .then((boundSocket) {
          if (bindTimedOut) {
            boundSocket.close();
          }
          return boundSocket;
        })
        .timeout(
          networkTimeout,
          onTimeout: () {
            bindTimedOut = true;
            throw TimeoutException('Telemetry socket bind timed out');
          },
        );
    // Consume asynchronous socket errors as well as synchronous send failures.
    // Assign before sending so finally can close the socket if sending throws.
    // ignore: cascade_invocations
    socket
      ..listen((_) {}, onError: (Object _) {})
      ..send(utf8.encode(message), addresses.first, 4040);
  } catch (_) {
    // Missing AAAA records, IPv4-only networks and socket errors are expected.
  } finally {
    socket?.close();
  }
}

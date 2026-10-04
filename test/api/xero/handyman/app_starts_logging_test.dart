import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/api/xero/handyman/app_starts_logging.dart';
import 'package:mocktail/mocktail.dart';

class _Socket extends Mock implements RawDatagramSocket {}

void main() {
  final address = InternetAddress.loopbackIPv6;
  late _Socket socket;

  setUpAll(() {
    registerFallbackValue(address);
  });

  setUp(() {
    socket = _Socket();
    when(
      () => socket.listen(any(), onError: any(named: 'onError')),
    ).thenAnswer((_) => const Stream<RawSocketEvent>.empty().listen((_) {}));
    when(() => socket.send(any(), any(), any())).thenReturn(1);
  });

  Future<List<InternetAddress>> lookup(
    String host, {
    InternetAddressType type = InternetAddressType.any,
  }) async {
    expect(host, 'telemetry.example.com');
    expect(type, InternetAddressType.IPv6);
    return [address];
  }

  Future<RawDatagramSocket> bind(InternetAddress host, int port) async {
    expect(host.address, InternetAddress.anyIPv6.address);
    expect(port, 0);
    return socket;
  }

  test('sends unchanged UTF-8 YAML to IPv6 on port 4040 and closes', () async {
    await sendAppStartupTelemetry(
      'Élan Home Repairs',
      targetHost: 'telemetry.example.com',
      startedAt: DateTime.utc(2026, 9, 26),
      appVersion: '1.2.3',
      lookup: lookup,
      bind: bind,
    );
    final data =
        verify(() => socket.send(captureAny(), address, 4040)).captured.single
            as List<int>;
    expect(utf8.decode(data), '''
start: "2026-09-26T00:00:00.000Z"
business name: "É*** H*** R******"
app version: "1.2.3"
''');
    verify(() => socket.close()).called(1);
  });

  test('missing AAAA records skip socket creation', () async {
    await sendAppStartupTelemetry(
      'Example',
      targetHost: 'telemetry.example.com',
      lookup: (_, {type = InternetAddressType.any}) async => [],
      bind: (_, _) async => fail('Must not bind without an IPv6 address'),
    );
  });

  test('DNS failure is harmless', () async {
    await sendAppStartupTelemetry(
      'Example',
      targetHost: 'telemetry.example.com',
      lookup: (_, {type = InternetAddressType.any}) async =>
          throw const SocketException('DNS failed'),
      bind: (_, _) async => fail('Must not bind after DNS failure'),
    );
  });

  test('DNS wait is bounded', () async {
    final pending = Completer<List<InternetAddress>>();
    await sendAppStartupTelemetry(
      'Example',
      targetHost: 'telemetry.example.com',
      networkTimeout: const Duration(milliseconds: 10),
      lookup: (_, {type = InternetAddressType.any}) => pending.future,
      bind: (_, _) async => fail('Must not bind after DNS timeout'),
    ).timeout(const Duration(seconds: 1));
    pending.completeError(const SocketException('Late DNS failure'));
    await Future<void>.delayed(Duration.zero);
  });

  test('unavailable IPv6 socket is harmless', () async {
    await sendAppStartupTelemetry(
      'Example',
      targetHost: 'telemetry.example.com',
      lookup: lookup,
      bind: (_, _) async => throw const SocketException('IPv6 unavailable'),
    );
  });

  test('send failure still closes the socket', () async {
    when(
      () => socket.send(any(), any(), any()),
    ).thenThrow(const SocketException('Network unreachable'));
    await sendAppStartupTelemetry(
      'Example',
      targetHost: 'telemetry.example.com',
      lookup: lookup,
      bind: bind,
    );
    verify(() => socket.close()).called(1);
  });

  test(
    'socket completing after bind timeout is closed without sending',
    () async {
      final pending = Completer<RawDatagramSocket>();
      await sendAppStartupTelemetry(
        'Example',
        targetHost: 'telemetry.example.com',
        networkTimeout: const Duration(milliseconds: 10),
        lookup: lookup,
        bind: (_, _) => pending.future,
      ).timeout(const Duration(seconds: 1));
      pending.complete(socket);
      await Future<void>.delayed(Duration.zero);
      verify(() => socket.close()).called(1);
      verifyNever(() => socket.send(any(), any(), any()));
    },
  );

  test('late bind failure is consumed', () async {
    final pending = Completer<RawDatagramSocket>();
    await sendAppStartupTelemetry(
      'Example',
      targetHost: 'telemetry.example.com',
      networkTimeout: const Duration(milliseconds: 10),
      lookup: lookup,
      bind: (_, _) => pending.future,
    );
    pending.completeError(const SocketException('Late bind failure'));
    await Future<void>.delayed(Duration.zero);
  });

  test('IPv6 loopback collector receives the unchanged record', () async {
    final collector = await RawDatagramSocket.bind(address, 4040);
    final received = Completer<Datagram>();
    collector.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = collector.receive();
        if (datagram != null && !received.isCompleted) {
          received.complete(datagram);
        }
      }
    });
    try {
      await sendAppStartupTelemetry(
        'Example Business',
        targetHost: '::1',
        startedAt: DateTime.utc(2026, 9, 26),
        appVersion: '1.2.3',
      );
      final datagram = await received.future.timeout(
        const Duration(seconds: 2),
      );
      expect(datagram.address.type, InternetAddressType.IPv6);
      expect(utf8.decode(datagram.data), '''
start: "2026-09-26T00:00:00.000Z"
business name: "E****** B*******"
app version: "1.2.3"
''');
    } finally {
      collector.close();
    }
  });
}

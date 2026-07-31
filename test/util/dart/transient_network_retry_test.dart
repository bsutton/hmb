import 'dart:async';
import 'dart:io';

import 'package:hmb/util/dart/transient_network_retry.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test('retries a temporary DNS failure with backoff', () async {
    var attempts = 0;
    final delays = <Duration>[];

    final result = await retryTransientNetworkOperation(
      () {
        attempts++;
        if (attempts < 3) {
          return Future<String>.error(
            const SocketException('Failed host lookup'),
          );
        }
        return Future.value('uploaded');
      },
      initialDelay: const Duration(milliseconds: 10),
      delay: (duration) async => delays.add(duration),
    );

    expect(result, 'uploaded');
    expect(attempts, 3);
    expect(delays, const [
      Duration(milliseconds: 10),
      Duration(milliseconds: 20),
    ]);
  });

  test('retries HTTP client transport failures', () async {
    var attempts = 0;

    await expectLater(
      retryTransientNetworkOperation<void>(() {
        attempts++;
        return Future<void>.error(
          http.ClientException('SocketException: Failed host lookup'),
        );
      }, delay: (_) async {}),
      throwsA(isA<http.ClientException>()),
    );

    expect(attempts, 3);
  });

  test('does not retry non-transport failures', () async {
    var attempts = 0;

    await expectLater(
      retryTransientNetworkOperation<void>(() {
        attempts++;
        return Future<void>.error(TimeoutException('operation timed out'));
      }, delay: (_) async {}),
      throwsA(isA<TimeoutException>()),
    );

    expect(attempts, 1);
  });
}

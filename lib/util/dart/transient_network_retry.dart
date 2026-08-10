import 'dart:io';

import 'package:http/http.dart' as http;

typedef RetryDelay = Future<void> Function(Duration duration);

/// Retries transport failures that commonly occur while a device changes
/// network or DNS is temporarily unavailable.
Future<T> retryTransientNetworkOperation<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 1),
  RetryDelay delay = Future<void>.delayed,
}) async {
  if (maxAttempts < 1) {
    throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be positive');
  }

  for (var attempt = 1; ; attempt++) {
    try {
      return await operation();
    } on Object catch (error) {
      if (attempt >= maxAttempts || !isTransientNetworkError(error)) {
        rethrow;
      }
      await delay(initialDelay * attempt);
    }
  }
}

bool isTransientNetworkError(Object error) =>
    error is SocketException || error is http.ClientException;

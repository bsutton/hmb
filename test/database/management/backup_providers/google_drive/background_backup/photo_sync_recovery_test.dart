@Tags(['flutter'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/management/backup_providers/google_drive/background_backup/photo_sync_recovery.dart';

void main() {
  testWidgets('network returns: retry drains pending queue without a tap', (
    tester,
  ) async {
    var attempts = 0;
    final pending = <int>[1, 2];
    final uploaded = <int>[];
    final recovery = PhotoSyncRecovery(
      run: (_) async {
        attempts++;
        if (attempts == 1) {
          uploaded.add(pending.removeAt(0));
          throw const SocketException('network lost');
        }
        uploaded.addAll(pending);
        pending.clear();
      },
      stop: () {},
      isRecoverable: (error) => error is SocketException,
      onChanged: () {},
      onError: (_) {},
    );
    await recovery.start();
    expect(recovery.isRunning, isFalse);
    expect(recovery.lastError, isA<SocketException>());
    await tester.pump(const Duration(seconds: 3));
    expect(attempts, 2);
    expect(uploaded, [1, 2]);
    expect(pending, isEmpty);
    expect(recovery.isWaiting, isFalse);
  });

  testWidgets('first retry starts; repeated starts never overlap workers', (
    tester,
  ) async {
    var attempts = 0;
    final done = Completer<void>();
    final recovery = PhotoSyncRecovery(
      run: (_) async {
        if (++attempts == 1) {
          throw const SocketException('offline');
        }
        await done.future;
      },
      stop: () {},
      isRecoverable: (_) => true,
      onChanged: () {},
      onError: (_) {},
    );
    await recovery.start();
    final retry = recovery.start();
    await recovery.start();
    expect(attempts, 2);
    expect(recovery.isRunning, isTrue);
    await tester.pump(const Duration(seconds: 30));
    expect(attempts, 2);
    done.complete();
    await retry;
  });

  testWidgets(
    'background/resume waits for worker shutdown and acknowledgements',
    (tester) async {
      var attempts = 0;
      var stops = 0;
      final drained = Completer<void>();
      late bool Function() interrupted;
      final recovery = PhotoSyncRecovery(
        run: (isInterrupted) async {
          if (++attempts == 1) {
            interrupted = isInterrupted;
            await drained.future;
          }
        },
        stop: () => stops++,
        isRecoverable: (_) => true,
        onChanged: () {},
        onError: (_) {},
      );
      final first = recovery.start();
      recovery.pause();
      expect(recovery.isRunning, isFalse);
      expect(interrupted(), isTrue);
      final resumed = recovery.resume();
      final repeated = recovery.resume();
      expect(attempts, 1);
      drained.complete();
      await Future.wait([first, resumed, repeated]);
      expect(attempts, 2);
      expect(stops, 1);
    },
  );

  testWidgets('cancel during startup survives foreground and timer events', (
    tester,
  ) async {
    var attempts = 0;
    final startup = Completer<void>();
    var uploads = 0;
    final recovery = PhotoSyncRecovery(
      run: (interrupted) async {
        attempts++;
        await startup.future;
        if (!interrupted()) {
          uploads++;
        }
      },
      stop: () {},
      isRecoverable: (_) => true,
      onChanged: () {},
      onError: (_) {},
    );
    final first = recovery.start();
    recovery
      ..cancel()
      ..pause();
    await recovery.resume();
    startup.complete();
    await first;
    await tester.pump(const Duration(minutes: 2));
    expect(attempts, 1);
    expect(uploads, 0);
    await recovery.start();
    expect(uploads, 1);
  });

  testWidgets('backoff is capped and cancel clears pending retry', (
    tester,
  ) async {
    var attempts = 0;
    final recovery = PhotoSyncRecovery(
      run: (_) {
        attempts++;
        return Future<void>.error(const SocketException('offline'));
      },
      stop: () {},
      isRecoverable: (_) => true,
      onChanged: () {},
      onError: (_) {},
      maxRetryDelay: const Duration(seconds: 6),
    );
    await recovery.start();
    await tester.pump(const Duration(seconds: 3));
    expect(attempts, 2);
    await tester.pump(const Duration(seconds: 5));
    expect(attempts, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(attempts, 3);
    await tester.pump(const Duration(seconds: 6));
    expect(attempts, 4);
    recovery.cancel();
    await tester.pump(const Duration(minutes: 2));
    await recovery.resume();
    expect(attempts, 4);
  });

  testWidgets('permanent errors remain available and do not auto retry', (
    tester,
  ) async {
    var attempts = 0;
    final recovery = PhotoSyncRecovery(
      run: (_) {
        attempts++;
        return Future<void>.error(StateError('403 forbidden'));
      },
      stop: () {},
      isRecoverable: (_) => false,
      onChanged: () {},
      onError: (_) {},
    );
    await recovery.start();
    await tester.pump(const Duration(minutes: 2));
    expect(attempts, 1);
    expect(recovery.lastError.toString(), contains('403 forbidden'));
    expect(recovery.isRunning, isFalse);
  });
}

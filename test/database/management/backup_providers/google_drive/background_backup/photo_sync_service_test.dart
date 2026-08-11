@Tags(['flutter'])
// ignore_for_file: lines_longer_than_80_chars
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/management/backup_providers/google_drive/background_backup/photo_sync_service.dart';

void main() {
  group('photo sync sign-in resume', () {
    late StreamController<bool> authStateChanges;
    late StreamSubscription<bool> subscription;
    var waitingForSignIn = false;
    var running = false;
    var startCalls = 0;
    var waitingWhenStarted = true;

    setUp(() {
      waitingForSignIn = false;
      running = false;
      startCalls = 0;
      waitingWhenStarted = true;
      authStateChanges = StreamController<bool>.broadcast(sync: true);
      subscription = listenForPhotoSyncSignIn(
        authStateChanges: authStateChanges.stream,
        isWaitingForSignIn: () => waitingForSignIn,
        isRunning: () => running,
        clearWaitingForSignIn: () => waitingForSignIn = false,
        start: () async {
          startCalls++;
          waitingWhenStarted = waitingForSignIn;
        },
      );
    });

    tearDown(() async {
      await subscription.cancel();
      await authStateChanges.close();
    });

    test('starts once when sign-in completes while sync is waiting', () {
      waitingForSignIn = true;

      authStateChanges
        ..add(true)
        ..add(true);

      expect(startCalls, 1);
      expect(waitingForSignIn, isFalse);
      expect(waitingWhenStarted, isFalse);
    });

    test('ignores auth events when resume conditions are not met', () {
      waitingForSignIn = true;
      authStateChanges.add(false);
      expect(startCalls, 0);
      expect(waitingForSignIn, isTrue);

      running = true;
      authStateChanges.add(true);
      expect(startCalls, 0);
      expect(waitingForSignIn, isTrue);

      running = false;
      waitingForSignIn = false;
      authStateChanges.add(true);
      expect(startCalls, 0);
    });
  });

  group('isRecoverablePhotoSyncError', () {
    test('matches transient network and sleep interruption messages', () {
      expect(
        isRecoverablePhotoSyncError(
          'SocketException: Software caused connection abort',
        ),
        isTrue,
      );
      expect(
        isRecoverablePhotoSyncError(
          'ClientException: Connection closed before full header was received',
        ),
        isTrue,
      );
      expect(
        isRecoverablePhotoSyncError(
          'TimeoutException: Timed out after 120s while uploading photo 12.',
        ),
        isTrue,
      );
      expect(
        isRecoverablePhotoSyncError('SocketException: Failed host lookup'),
        isTrue,
      );
    });

    test('does not match permanent service errors', () {
      expect(
        isRecoverablePhotoSyncError(
          'HttpException: Failed to initialize resumable upload: 403 forbidden',
        ),
        isFalse,
      );
      expect(
        isRecoverablePhotoSyncError('StateError: Google Drive auth missing'),
        isFalse,
      );
    });
  });
}

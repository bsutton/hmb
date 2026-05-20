@Tags(['flutter'])
// ignore_for_file: lines_longer_than_80_chars
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/management/backup_providers/google_drive/background_backup/photo_sync_service.dart';

void main() {
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

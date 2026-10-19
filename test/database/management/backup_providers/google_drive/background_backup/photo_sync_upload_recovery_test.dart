@Tags(['flutter'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hmb/database/management/backup_providers/google_drive/background_backup/photo_sync_params.dart';
import 'package:hmb/database/management/backup_providers/google_drive/background_backup/photo_sync_service.dart';
import 'package:hmb/database/management/backup_providers/google_drive/background_backup/upload_photos_in_backup.dart';
import 'package:hmb/database/management/backup_providers/google_drive/google_drive_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Drive extends Fake implements GoogleDriveApi {
  _Drive(this.digest) {
    client = MockClient((request) async {
      expect(request.url.queryParameters['q'], contains("'folder' in parents"));
      expect(request.url.queryParameters['q'], contains("value='42'"));
      return http.Response(
        jsonEncode({
          'files': committed
              ? [
                  {'id': 'remote42', 'md5Checksum': digest},
                ]
              : <Map<String, String>>[],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  }

  final String digest;
  late final http.Client client;
  var committed = false;
  var creates = 0;
  var uploads = 0;

  @override
  drive.FilesResource get files => drive.DriveApi(client).files;

  @override
  Future<String> getPhotoSyncFolder() async => 'folder';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST') {
      creates++;
      return http.StreamedResponse(
        const Stream.empty(),
        200,
        headers: {'location': 'https://fixture.invalid/upload'},
      );
    }
    expect(request.method, 'PUT');
    await request.finalize().drain<void>();
    uploads++;
    committed = true;
    throw const SocketException('response lost after server committed upload');
  }

  @override
  void close() {}
}

void main() {
  test(
    'lost upload response is reconciled without creating/uploading twice',
    () async {
      final directory = await Directory.systemTemp.createTemp('hmb-sync-test');
      final file = File('${directory.path}/fixture.jpg');
      final bytes = utf8.encode('synthetic photo fixture');
      await file.writeAsBytes(bytes);
      final api = _Drive(md5.convert(bytes).toString());
      final port = ReceivePort();
      final received = <Object?>[];
      final subscription = port.listen(received.add);
      final payload = PhotoPayload(
        id: 42,
        absolutePathToLocalPhoto: file.path,
        createdAt: DateTime(2026),
        pathToCloudStorage: 'fixture.jpg',
      );
      Future<void> sync() => uploadPhotosInBackup(
        sendPort: port.sendPort,
        authHeaders: const {},
        photoPayloads: [payload],
        deletePayloads: const [],
        createApi: (_) async => api,
      );
      try {
        await expectLater(sync(), throwsA(isA<SocketException>()));
        await sync();
        await Future<void>.delayed(Duration.zero);
        expect(api.creates, 1);
        expect(api.uploads, 1);
        final acknowledgements = received.whereType<PhotoUploaded>().toList();
        expect(acknowledgements, hasLength(1));
        expect(acknowledgements.single.cloudFileId, 'remote42');
      } finally {
        await subscription.cancel();
        port.close();
        api.client.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

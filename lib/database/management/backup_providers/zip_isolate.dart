import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:dcli_core/dcli_core.dart';
import 'package:path/path.dart';
import 'package:sentry/sentry.dart';

import 'backup_provider.dart';

/// All photos are stored under this path in the zip file
const zipPhotoRoot = 'photos/';

Future<void> zipBackup(
    {required BackupProvider provider,
    required String pathToZip,
    required String pathToBackupFile,
    required bool includePhotos}) async {
  // Set up communication channels
  final receivePort = ReceivePort();
  final errorPort = ReceivePort();
  final exitPort = ReceivePort();

  // Start the zipping isolate
  await Isolate.spawn<_ZipParams>(
    _zipFiles,
    _ZipParams(
      sendPort: receivePort.sendPort,
      pathToZip: pathToZip,
      pathToBackupFile: pathToBackupFile,
      includePhotos: includePhotos,
      photosRootPath: await provider.photosRootPath,
      zipPhotoRoot: zipPhotoRoot,
      progressStageStart: 3,
      progressStageEnd: 5,
    ),
    onError: errorPort.sendPort,
    onExit: exitPort.sendPort,
  );

  // Listen for progress updates from the isolate
  final completer = Completer<void>();
  errorPort.listen((error) {
    Sentry.captureException(error);
    completer.completeError(error as Object);
  });
  exitPort.listen((message) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });
  receivePort.listen((message) {
    if (message is ProgressUpdate) {
      provider.emitProgress(
        message.stageDescription,
        message.stageNo,
        message.stageCount,
      );
    }
  });

  // Wait for the isolate to finish
  await completer.future;

  receivePort.close();
  errorPort.close();
  exitPort.close();
}

// _ZipParams class

// _zipFiles function
Future<void> _zipFiles(_ZipParams params) async {
  await Sentry.init(
    (options) {
      options
        ..dsn =
            'https://17bb41df4a5343530bfcb92553f4c5a7@o4507706035994624.ingest.us.sentry.io/4507706038157312'
        ..tracesSampleRate = 1.0;
    },
  );

  final encoder = ZipFileEncoder();
  final sendPort = params.sendPort;

  try {
    encoder.create(params.pathToZip);

    // Emit progress: Zipping database
    sendPort.send(ProgressUpdate('Zipping database ${params.pathToBackupFile}',
        params.progressStageStart, params.progressStageEnd));

    await encoder.addFile(File(params.pathToBackupFile));

    if (params.includePhotos) {
      sendPort.send(ProgressUpdate('Adding photos ${params.photosRootPath}',
          params.progressStageStart, params.progressStageEnd));
      var processedPhotos = 0;
      final photos =
          await findAsync('*.jpg', workingDirectory: params.photosRootPath)
              .toList();
      final totalPhotos = photos.length;
      sendPort.send(ProgressUpdate('Found $totalPhotos photos',
          params.progressStageStart, params.progressStageEnd));

      for (final item in photos) {
        // sendPort.send(ProgressUpdate('Adding photo $processedPhotos/$totalPhotos photos',
        //     params.progressStageStart, params.progressStageEnd));

        final relativePhotoPath =
            relative(item.pathTo, from: params.photosRootPath);
        final zipPath = join(params.zipPhotoRoot, relativePhotoPath);

        // sendPort.send(ProgressUpdate('Calling add file ${item.pathTo}',
        //     params.progressStageStart, params.progressStageEnd));

        await encoder.addFile(File(item.pathTo), zipPath);

        // sendPort.send(ProgressUpdate('add file completed ${item.pathTo}',
        //     params.progressStageStart, params.progressStageEnd));

        processedPhotos++;

        // Emit progress for each photo
        final stageNo = params.progressStageStart +
            ((processedPhotos / totalPhotos) *
                    (params.progressStageEnd - params.progressStageStart))
                .toInt();
        sendPort.send(ProgressUpdate(
            'Zipping photos ($processedPhotos/$totalPhotos)',
            stageNo,
            params.progressStageEnd));
      }
    }

    await encoder.close();

    // Notify completion
    sendPort.send(ProgressUpdate(
        'Zipping completed', params.progressStageEnd, params.progressStageEnd));
    // ignore: avoid_catches_without_on_clauses
  } catch (e, st) {
    await Sentry.captureException(e, stackTrace: st);
    // Send error back to the main isolate
    sendPort.send(ProgressUpdate('Error during zipping: $e',
        params.progressStageEnd, params.progressStageEnd));
  }

  /// Isolate won't shutdown if we don't terminate sentry.
  await Sentry.close();
}

Future<String?> extractFiles(BackupProvider provider, File backupFile,
    String tmpDir, int stageNo, int stageCount) async {
  final encoder = ZipDecoder();
  String? dbPath;
  // Extract the ZIP file contents to a temporary directory
  final archive = encoder.decodeBuffer(InputFileStream(backupFile.path));

  const restored = 0;

  for (final file in archive) {
    final filename = file.name;
    final filePath = join(tmpDir, filename);

    provider.emitProgress(
        'Restoring  $restored/${archive.length}', stageNo, stageCount);

    if (file.isFile) {
      // If the file is the database extact it
      // to a temp dir and return the path.
      if (filename.endsWith('.db')) {
        dbPath = filePath;
        await _expandZippedFileToDisk(filePath, file);
      }

      // Write files to the temporary directory
      if (filename.startsWith(zipPhotoRoot)) {
        final parts = split(filename);
        final photoDestPath =
            joinAll([await provider.photosRootPath, ...parts.sublist(1)]);

        await _expandZippedFileToDisk(photoDestPath, file);
      }
    }
  }

  return dbPath;
}

Future<void> _expandZippedFileToDisk(
    String photoDestPath, ArchiveFile file) async {
  File(photoDestPath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(file.content as List<int>);
}

class _ZipParams {
  _ZipParams({
    required this.sendPort,
    required this.pathToZip,
    required this.pathToBackupFile,
    required this.includePhotos,
    required this.photosRootPath,
    required this.zipPhotoRoot,
    required this.progressStageStart,
    required this.progressStageEnd,
  });
  final SendPort sendPort;
  final String pathToZip;
  final String pathToBackupFile;
  final bool includePhotos;
  final String photosRootPath;
  final String zipPhotoRoot;
  final int progressStageStart;
  final int progressStageEnd;
}

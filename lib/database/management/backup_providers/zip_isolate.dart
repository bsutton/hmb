import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:dcli_core/dcli_core.dart';
import 'package:path/path.dart';

import '../database_helper.dart';
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
        photoFilePaths: await getAllPhotoPaths()),
    onError: errorPort.sendPort,
    onExit: exitPort.sendPort,
  );

  // Listen for progress updates from the isolate
  final completer = Completer<void>();
  errorPort.listen((error) => completer.completeError(error as Object));
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
}

// _ZipParams class

// _zipFiles function
Future<void> _zipFiles(_ZipParams params) async {
  final encoder = ZipFileEncoder();
  final sendPort = params.sendPort;

  try {
    encoder.create(params.pathToZip);

    // Emit progress: Zipping database
    sendPort.send(ProgressUpdate('Zipping database', params.progressStageStart,
        params.progressStageEnd));

    await encoder.addFile(File(params.pathToBackupFile));

    if (params.includePhotos) {
      final totalPhotos = params.photoFilePaths.length;
      var processedPhotos = 0;

      for (final relativePhotoPath in params.photoFilePaths) {
        final fullPathToPhoto = join(params.photosRootPath, relativePhotoPath);
        if (exists(fullPathToPhoto)) {
          final zipPath = join(params.zipPhotoRoot, relativePhotoPath);
          await encoder.addFile(File(fullPathToPhoto), zipPath);
        }
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
  } catch (e) {
    // Send error back to the main isolate
    sendPort.send(ProgressUpdate('Error during zipping: $e',
        params.progressStageEnd, params.progressStageEnd));
    Isolate.exit();
  }
}

/// We can't use DaoPhoto as it uses June which is a flutter component
/// and we need this to work from the cli.
Future<List<String>> getAllPhotoPaths() async {
  final db = DatabaseHelper.instance.database;
  final List<Map<String, dynamic>> maps =
      await db.query('photo', columns: ['filePath']);
  return maps.map((map) => map['filePath'] as String).toList();
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
    required this.photoFilePaths,
  });
  final SendPort sendPort;
  final String pathToZip;
  final String pathToBackupFile;
  final bool includePhotos;
  final String photosRootPath;
  final String zipPhotoRoot;
  final int progressStageStart;
  final int progressStageEnd;
  final List<String> photoFilePaths;
}

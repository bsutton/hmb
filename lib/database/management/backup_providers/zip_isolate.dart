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
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart';
import 'package:sentry/sentry.dart';

import 'backup_provider.dart';
import 'progress_update.dart';

/// All photos are stored under this path in the zip file
const zipPhotoRoot = 'photos/';

Future<void> zipBackup({
  required BackupProvider provider,
  required String pathToZip,
  required String pathToBackupFile,
}) async {
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
      photosRootPath: await provider.photosRootPath,
      zipPhotoRoot: zipPhotoRoot,
      progressStageStart: 3,
      progressStageEnd: 5,
    ),
    onError: errorPort.sendPort,
    onExit: exitPort.sendPort,
    debugName: 'zipBackup',
  );

  // Listen for progress updates from the isolate
  final completer = Completer<void>();
  errorPort.listen((error) {
    unawaited(Sentry.captureException(error));
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
  await Sentry.init((options) {
    options
      ..dsn =
          'https://17bb41df4a5343530bfcb92553f4c5a7@o4507706035994624.ingest.us.sentry.io/4507706038157312'
      ..tracesSampleRate = 1.0;
  });

  final encoder = ZipFileEncoder();
  final sendPort = params.sendPort;

  try {
    encoder.create(params.pathToZip);

    // Emit progress: Zipping database
    sendPort.send(
      ProgressUpdate(
        'Zipping database ${params.pathToBackupFile}',
        params.progressStageStart,
        params.progressStageEnd,
      ),
    );

    await encoder.addFile(File(params.pathToBackupFile));

    await encoder.close();

    // Notify completion
    sendPort.send(
      ProgressUpdate(
        'Zipping completed',
        params.progressStageEnd,
        params.progressStageEnd,
      ),
    );
    // ignore: avoid_catches_without_on_clauses
  } catch (e, st) {
    await Sentry.captureException(e, stackTrace: st);
    // Send error back to the main isolate
    sendPort.send(
      ProgressUpdate(
        'Error during zipping: $e',
        params.progressStageEnd,
        params.progressStageEnd,
      ),
    );
  }

  /// Isolate won't shutdown if we don't terminate sentry.
  await Sentry.close();
}

Future<String?> extractFiles(
  BackupProvider provider,
  File backupFile,
  String tmpDir,
  int stageNo,
  int stageCount,
) async {
  final encoder = ZipDecoder();
  String? dbPath;
  // Extract the ZIP file contents to a temporary directory
  final input = InputFileStream(backupFile.path);
  try {
    final archive = encoder.decodeStream(input);
    final targets = <({ArchiveFile file, String path})>[];

    // Check the complete archive before writing any entry. Backup files can be
    // replaced outside the app, so ZIP names are not trusted filesystem paths.
    for (final file in archive) {
      final segments = _safeArchiveSegments(file.name, isFile: file.isFile);
      if (!file.isFile) {
        continue;
      }
      // Current backups contain only the database. The apparent photo root is
      // actually the user's Documents directory on desktop platforms, so a
      // ZIP must never write a photo entry there.
      if (segments.first == 'photos') {
        throw const FormatException('Photo entries cannot be restored safely.');
      }
      if (segments.length == 1 && segments.single.endsWith('.db')) {
        final path = join(tmpDir, segments.single);
        _checkExtractionPath(tmpDir, path);
        targets.add((file: file, path: path));
      }
    }

    if (targets.length != 1) {
      throw const FormatException('Backup must contain one database file.');
    }

    const restored = 0;

    for (final target in targets) {
      final file = target.file;
      _checkExtractionPath(tmpDir, target.path);

      provider.emitProgress(
        'Restoring  $restored/${archive.length}',
        stageNo,
        stageCount,
      );

      dbPath = target.path;
      await _expandZippedFileToDisk(target.path, file);
    }
    return dbPath;
  } finally {
    await input.close();
  }
}

List<String> _safeArchiveSegments(String name, {required bool isFile}) {
  if (name.isEmpty ||
      name.contains(r'\') ||
      name.contains(':') ||
      name.contains('\u0000')) {
    throw const FormatException('Unsafe backup entry name.');
  }
  final segments = name.split('/');
  if (!isFile && segments.last.isEmpty) {
    segments.removeLast();
  }
  if (segments.isEmpty ||
      segments.any(
        (segment) => segment.isEmpty || segment == '.' || segment == '..',
      )) {
    throw const FormatException('Unsafe backup entry name.');
  }
  return segments;
}

void _checkExtractionPath(String root, String path) {
  final base = normalize(absolute(root));
  final destination = normalize(absolute(path));
  if (!isWithin(base, destination)) {
    throw const FormatException('Backup entry escapes restore directory.');
  }
  var current = base;
  if (FileSystemEntity.typeSync(current, followLinks: false) ==
      FileSystemEntityType.link) {
    throw const FormatException('Backup restore path contains a symlink.');
  }
  for (final segment in split(relative(destination, from: base))) {
    current = join(current, segment);
    if (FileSystemEntity.typeSync(current, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FormatException('Backup restore path contains a symlink.');
    }
  }
}

Future<void> _expandZippedFileToDisk(
  String photoDestPath,
  ArchiveFile file,
) async {
  File(photoDestPath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(file.content as List<int>);
}

class _ZipParams {
  final SendPort sendPort;
  final String pathToZip;
  final String pathToBackupFile;
  final String photosRootPath;
  final String zipPhotoRoot;
  final int progressStageStart;
  final int progressStageEnd;

  _ZipParams({
    required this.sendPort,
    required this.pathToZip,
    required this.pathToBackupFile,
    required this.photosRootPath,
    required this.zipPhotoRoot,
    required this.progressStageStart,
    required this.progressStageEnd,
  });
}

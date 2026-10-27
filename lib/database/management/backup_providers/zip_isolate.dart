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
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart';
import 'package:sentry/sentry.dart';

import 'backup_provider.dart';
import 'progress_update.dart';

/// All photos are stored under this path in the zip file
const zipPhotoRoot = 'photos/';

/// Database-only backups are bounded so a ZIP bomb cannot exhaust disk space.
const int maxRestoredDatabaseBytes = 512 * 1024 * 1024;
const int maxBackupArchiveBytes = 256 * 1024 * 1024;
const int _maxCentralDirectoryBytes = 8 * 1024 * 1024;

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
  int stageCount, {
  int maxDatabaseBytes = maxRestoredDatabaseBytes,
}) async {
  final selected = await _preflightZipMetadata(backupFile, maxDatabaseBytes);
  final path = join(tmpDir, selected.name);
  _checkExtractionPath(tmpDir, path);
  final input = InputFileStream(backupFile.path);
  try {
    final record = InputMemoryStream(selected.header.sublist(4));
    final header = ZipFileHeader()..read(record, fileBytes: input);
    if (header.filename != selected.name ||
        header.uncompressedSize != selected.size ||
        header.file == null) {
      throw const FormatException('Backup ZIP database entry changed.');
    }
    final local = header.file!;
    final expectedCompression = header.compressionMethod == 0
        ? CompressionType.none
        : CompressionType.deflate;
    if (local.filename != header.filename ||
        local.flags != header.generalPurposeBitFlag ||
        local.compressionMethod != expectedCompression) {
      throw const FormatException('Backup ZIP headers disagree.');
    }
    final file = ArchiveFile.file(selected.name, selected.size, local);
    _checkExtractionPath(tmpDir, path);
    provider.emitProgress('Restoring database', stageNo, stageCount);
    await _expandZippedFileToDisk(path, file, maxDatabaseBytes, selected.crc32);
    return path;
  } finally {
    await input.close();
  }
}

/// Inspect raw directory records before any archive entry is decompressed.
/// Extraction then reads only this selected record, so ZIP64 and ambiguous
/// comment records cannot redirect a separate decoder to unchecked metadata.
Future<({Uint8List header, String name, int size, int crc32})>
_preflightZipMetadata(File backup, int maxDatabaseBytes) async {
  final input = await backup.open();
  try {
    final length = await input.length();
    if (length > maxBackupArchiveBytes || length < 22) {
      throw const FormatException('Backup ZIP size is invalid.');
    }
    const maxTail = 22 + 0xffff;
    final tailStart = length > maxTail ? length - maxTail : 0;
    await input.setPosition(tailStart);
    final tail = Uint8List.fromList(await input.read(length - tailStart));
    final tailData = ByteData.sublistView(tail);
    int? eocd;
    for (var offset = tail.length - 22; offset >= 0; offset--) {
      if (tailData.getUint32(offset, Endian.little) == 0x06054b50 &&
          offset + 22 + tailData.getUint16(offset + 20, Endian.little) ==
              tail.length) {
        eocd = offset;
        break;
      }
    }
    if (eocd == null) {
      throw const FormatException('Backup ZIP has no valid directory.');
    }
    final disk = tailData.getUint16(eocd + 4, Endian.little);
    final startDisk = tailData.getUint16(eocd + 6, Endian.little);
    final diskEntries = tailData.getUint16(eocd + 8, Endian.little);
    final totalEntries = tailData.getUint16(eocd + 10, Endian.little);
    final directorySize = tailData.getUint32(eocd + 12, Endian.little);
    final directoryOffset = tailData.getUint32(eocd + 16, Endian.little);
    if (disk != 0 ||
        startDisk != 0 ||
        diskEntries != totalEntries ||
        totalEntries == 0 ||
        totalEntries > 1024 ||
        directorySize == 0 ||
        directorySize > _maxCentralDirectoryBytes ||
        directoryOffset > tailStart + eocd - directorySize) {
      throw const FormatException('Backup ZIP directory is invalid.');
    }
    await input.setPosition(directoryOffset);
    final bytes = Uint8List.fromList(await input.read(directorySize));
    if (bytes.length != directorySize) {
      throw const FormatException('Backup ZIP directory is truncated.');
    }
    final directory = ByteData.sublistView(bytes);
    var cursor = 0;
    ({Uint8List header, String name, int size, int crc32})? selected;
    for (var index = 0; index < totalEntries; index++) {
      if (cursor > bytes.length - 46 ||
          directory.getUint32(cursor, Endian.little) != 0x02014b50) {
        throw const FormatException('Backup ZIP entry metadata is invalid.');
      }
      final versionMadeBy = directory.getUint16(cursor + 4, Endian.little);
      final flags = directory.getUint16(cursor + 8, Endian.little);
      final method = directory.getUint16(cursor + 10, Endian.little);
      final crc32 = directory.getUint32(cursor + 16, Endian.little);
      final compressed = directory.getUint32(cursor + 20, Endian.little);
      final uncompressed = directory.getUint32(cursor + 24, Endian.little);
      final nameLength = directory.getUint16(cursor + 28, Endian.little);
      final extraLength = directory.getUint16(cursor + 30, Endian.little);
      final commentLength = directory.getUint16(cursor + 32, Endian.little);
      final attributes = directory.getUint32(cursor + 38, Endian.little);
      final localOffset = directory.getUint32(cursor + 42, Endian.little);
      final entryLength = 46 + nameLength + extraLength + commentLength;
      if (entryLength > bytes.length - cursor ||
          nameLength == 0 ||
          (flags & 1) != 0 ||
          (method != 0 && method != 8) ||
          compressed == 0xffffffff ||
          uncompressed == 0xffffffff ||
          uncompressed > maxDatabaseBytes ||
          localOffset == 0xffffffff ||
          localOffset >= directoryOffset ||
          (versionMadeBy >> 8 == 3 &&
              ((attributes >> 16) & 0xf000) == 0xa000)) {
        throw const FormatException('Unsafe backup ZIP entry metadata.');
      }
      final name = utf8.decode(
        bytes.sublist(cursor + 46, cursor + 46 + nameLength),
      );
      final isFile = !name.endsWith('/');
      final segments = _safeArchiveSegments(name, isFile: isFile);
      if (isFile && segments.first == 'photos') {
        throw const FormatException('Photo entries cannot be restored safely.');
      }
      if (isFile && segments.length == 1 && segments.single.endsWith('.db')) {
        if (selected != null) {
          throw const FormatException('Backup has multiple database entries.');
        }
        selected = (
          header: bytes.sublist(cursor, cursor + entryLength),
          name: name,
          size: uncompressed,
          crc32: crc32,
        );
      }
      cursor += entryLength;
    }
    if (cursor != bytes.length) {
      throw const FormatException('Backup ZIP directory size is inconsistent.');
    }
    if (selected == null) {
      throw const FormatException('Backup must contain one database file.');
    }
    return selected;
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
  String destination,
  ArchiveFile file,
  int maxBytes,
  int expectedCrc32,
) async {
  final output = OutputFileStream(destination);
  try {
    file.writeContent(_BoundedOutputStream(output, maxBytes));
    if (output.length != file.size) {
      throw const FormatException('Backup database size does not match ZIP.');
    }
    await output.close();
    var crc32 = 0;
    await for (final chunk in File(destination).openRead()) {
      crc32 = getCrc32(chunk, crc32);
    }
    if (crc32 != expectedCrc32) {
      throw const FormatException('Backup database checksum is invalid.');
    }
  } catch (_) {
    await output.close();
    final incomplete = File(destination);
    if (incomplete.existsSync()) {
      await incomplete.delete();
    }
    rethrow;
  }
}

class _BoundedOutputStream extends OutputStream {
  final OutputStream _target;
  final int _maxBytes;

  _BoundedOutputStream(this._target, this._maxBytes)
    : super(byteOrder: _target.byteOrder);

  @override
  int get length => _target.length;

  @override
  bool get isOpen => _target.isOpen;

  void _check(int count) {
    if (count < 0 || length > _maxBytes - count) {
      throw const FormatException('Backup database exceeds size limit.');
    }
  }

  @override
  void clear() => _target.clear();

  @override
  void flush() => _target.flush();

  @override
  Future<void> close() => _target.close();

  @override
  void closeSync() => _target.closeSync();

  @override
  void writeByte(int value) {
    _check(1);
    _target.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final count = length ?? bytes.length;
    _check(count);
    _target.writeBytes(bytes, length: count);
  }

  @override
  void writeStream(InputStream stream) {
    while (!stream.isEOS) {
      final chunk = stream.readBytes(64 * 1024).toUint8List();
      if (chunk.isEmpty) {
        break;
      }
      writeBytes(chunk);
    }
  }

  @override
  void writeBackReference(int distance, int count) {
    _check(count);
    _target.writeBackReference(distance, count);
  }

  @override
  Uint8List subset(int start, [int? end]) => _target.subset(start, end);
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

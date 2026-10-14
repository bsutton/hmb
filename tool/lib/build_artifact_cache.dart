import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'android_validation.dart';

/// Preserves upgrade inputs across cleans and failed builds. Only a successful
/// Android validation advances the last-validated pointer.
class BuildArtifactCache {
  BuildArtifactCache({String directory = '.android-artifacts'})
    : directory = Directory(p.absolute(directory));

  final Directory directory;

  /// Reuse a completed validation only for the exact APK/AAB bytes recorded.
  Future<ValidatedArtifact?> validatedCandidate(String path) async {
    final extension = _extension(path);
    final record = _readRecord(extension);
    if (record == null || !File(path).existsSync()) {
      return null;
    }
    final candidate = await ValidatedArtifact.capture(path);
    if (candidate.digest != record['validated']) {
      return null;
    }
    await _resolveDigest(candidate.digest, extension);
    return candidate;
  }

  /// Preserve both kinds of output before a clean removes either one.
  Future<void> preserveExistingOutput(String path) async {
    final extension = _extension(path);
    final bootstrap = File('${directory.path}/bootstrap$extension.json');
    if (_readRecord(extension) == null &&
        !bootstrap.existsSync() &&
        File(path).existsSync()) {
      _writeJson(bootstrap, await _preserve(await _capture(path)));
    }
  }

  Future<String> resolvePrevious({
    required String candidatePath,
    required bool building,
    String? explicitPath,
  }) async {
    final extension = _extension(candidatePath);
    final String digest;
    if (explicitPath != null && explicitPath.trim().isNotEmpty) {
      if (_extension(explicitPath) != extension) {
        throw StateError('The previous artifact must also be an $extension.');
      }
      digest = await _preserve(await _capture(explicitPath));
    } else {
      final record = _readRecord(extension);
      if (record != null) {
        final candidate = !building && File(candidatePath).existsSync()
            ? await ValidatedArtifact.capture(candidatePath)
            : null;
        // Reinstalling the latest validated artifact still tests the upgrade
        // from its predecessor, not an invalid same-version upgrade.
        digest = candidate?.digest == record['validated']
            ? record['previous']!
            : record['validated']!;
      } else {
        final bootstrap = File('${directory.path}/bootstrap$extension.json');
        if (bootstrap.existsSync()) {
          digest = jsonDecode(bootstrap.readAsStringSync()) as String;
        } else {
          if (!building || !File(candidatePath).existsSync()) {
            throw StateError(
              'No previous $extension is available yet. Supply '
              '--previous-artifact once to seed automatic upgrade validation.',
            );
          }
          // Preserve the pre-existing output before flutter clean. It must
          // pass previous-version startup as part of the validation gate.
          digest = await _preserve(await _capture(candidatePath));
          _writeJson(bootstrap, digest);
        }
      }
    }
    final preserved = await _resolveDigest(digest, extension);
    if (!building && File(candidatePath).existsSync()) {
      final candidate = await ValidatedArtifact.capture(candidatePath);
      if (candidate.digest == digest) {
        throw StateError(
          'The available baseline is the same APK as the install candidate. '
          'Run tool/build.dart to build the next version, or supply an older '
          '--previous-artifact.',
        );
      }
    }
    return preserved;
  }

  Future<void> recordValidated({
    required ValidatedArtifact candidate,
    required String previousPath,
  }) async {
    final extension = _extension(candidate.path);
    if (_extension(previousPath) != extension) {
      throw StateError('Candidate and baseline types must match.');
    }
    await candidate.assertUnchanged();
    final previous = await _preserve(await _capture(previousPath));
    final validated = await _preserve(candidate);
    if (previous == validated) {
      throw StateError('A validated upgrade must have distinct artifacts.');
    }
    _writeJson(File('${directory.path}/validated$extension.json'), {
      'validated': validated,
      'previous': previous,
    });
  }

  Map<String, String>? _readRecord(String extension) {
    final file = File('${directory.path}/validated$extension.json');
    if (!file.existsSync()) {
      return null;
    }
    final record = Map<String, String>.from(
      jsonDecode(file.readAsStringSync()) as Map,
    );
    if (!record.containsKey('validated') || !record.containsKey('previous')) {
      throw StateError('Incomplete artifact record: ${file.path}');
    }
    return record;
  }

  Future<ValidatedArtifact> _capture(String path) {
    if (!File(path).existsSync()) {
      throw StateError('Previous artifact does not exist: $path');
    }
    return ValidatedArtifact.capture(path);
  }

  Future<String> _preserve(ValidatedArtifact artifact) async {
    final extension = _extension(artifact.path);
    directory.createSync(recursive: true);
    final target = File('${directory.path}/${artifact.digest}$extension');
    await artifact.assertUnchanged();
    if (!target.existsSync()) {
      final temporary = directory.createTempSync('preserve-');
      try {
        final copy = await File(
          artifact.path,
        ).copy('${temporary.path}/artifact$extension');
        await artifact.verifyCopy(copy.path);
        await copy.rename(target.path);
      } finally {
        temporary.deleteSync(recursive: true);
      }
    }
    await artifact.verifyCopy(target.path);
    return artifact.digest;
  }

  Future<String> _resolveDigest(String digest, String extension) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw StateError('Invalid cached artifact digest.');
    }
    final artifact = await _capture('${directory.path}/$digest$extension');
    if (artifact.digest != digest) {
      throw StateError('Cached artifact changed: ${artifact.path}');
    }
    return artifact.path;
  }

  void _writeJson(File target, Object value) {
    directory.createSync(recursive: true);
    final temporary = directory.createTempSync('record-');
    try {
      File('${temporary.path}/record.json')
        ..writeAsStringSync(jsonEncode(value), flush: true)
        ..renameSync(target.path);
    } finally {
      temporary.deleteSync(recursive: true);
    }
  }

  String _extension(String path) {
    final extension = p.extension(path);
    if (extension != '.apk' && extension != '.aab') {
      throw StateError('Expected an APK or AAB: $path');
    }
    return extension;
  }
}

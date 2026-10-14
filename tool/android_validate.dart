#! /usr/bin/env dcli

import 'dart:io';

import 'package:dcli/dcli.dart';

import 'lib/android_validation.dart';
import 'lib/build_artifact_cache.dart';

/// Validate an artifact without a version bump or phone installation.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/android_validate.dart '
      '<candidate.apk|aab> <previous.apk|aab>',
    );
    exitCode = 64;
    return;
  }
  if (!exists(args[0]) || !exists(args[1])) {
    throw StateError('Candidate and previous artifact must exist');
  }
  final validated = await AndroidValidation(
    previousArtifact: args[1],
  ).validate(args[0]);
  await BuildArtifactCache().recordValidated(
    candidate: validated,
    previousPath: args[1],
  );
}

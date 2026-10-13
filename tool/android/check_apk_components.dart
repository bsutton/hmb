#!/usr/bin/env dcli

import 'dart:io';

import 'package:args/args.dart';
import 'package:dcli/dcli.dart';

// CLI helpers intentionally live outside the app package.
// ignore: avoid_relative_lib_imports
import '../lib/apk_components.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('apkanalyzer', defaultsTo: 'apkanalyzer');
  final options = parser.parse(args);
  final analyzer = options['apkanalyzer'] as String;
  if (!which(analyzer).found) {
    throw StateError('Missing $analyzer');
  }
  try {
    await checkApkComponents(options.rest, analyzer);
  } catch (error) {
    stderr.writeln('APK validation failed: $error');
    exitCode = 1;
  }
}

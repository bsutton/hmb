import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';

const _androidNamespace = 'http://schemas.android.com/apk/res/android';

/// Compare all manifests against the union of DEX definitions in a split set.
List<String> missingComponents(String manifest, String dexPackages) {
  final classes = dexPackages
      .split('\n')
      .where((line) => RegExp(r'^C\s+d\s').hasMatch(line))
      .map((line) => line.trim().split(RegExp(r'\s+')).last)
      .toSet();
  if (classes.isEmpty) {
    throw StateError('apkanalyzer returned no defined DEX classes');
  }
  final root = XmlDocument.parse(manifest).rootElement;
  final package = root.getAttribute('package');
  final app = root.getElement('application');
  if (root.name.local != 'manifest' || package == null || app == null) {
    throw StateError('APK has no manifest package/application');
  }
  final missing = <String>[];
  for (final node in [app, ...app.childElements]) {
    final kind = node.name.local;
    if (!{
          'application',
          'activity',
          'service',
          'receiver',
          'provider',
          'activity-alias',
        }.contains(kind) ||
        node.getAttribute('enabled', namespaceUri: _androidNamespace) ==
            'false') {
      continue;
    }
    for (final attribute in [
      if (kind == 'activity-alias') 'targetActivity' else 'name',
      if (kind == 'application') 'appComponentFactory',
    ]) {
      var name = node.getAttribute(attribute, namespaceUri: _androidNamespace);
      if (name == null || name.isEmpty) {
        continue;
      }
      if (name.startsWith('.')) {
        name = '$package$name';
      } else if (!name.contains('.')) {
        name = '$package.$name';
      }
      if (!name.startsWith('android.') && !classes.contains(name)) {
        missing.add(
          'Missing ${attribute == 'name' ? kind : attribute} class: $name',
        );
      }
    }
  }
  return missing;
}

Future<void> checkApkComponents(List<String> apks, String analyzer) async {
  if (apks.isEmpty) {
    throw ArgumentError('Supply at least one APK');
  }
  Future<String> analyze(String apk, List<String> command) async {
    final args = [...command, apk];
    final result = await Process.run(analyzer, args);
    if (result.exitCode != 0) {
      throw ProcessException(
        analyzer,
        args,
        '${result.stderr}',
        result.exitCode,
      );
    }
    return result.stdout as String;
  }

  final manifests = <String>[];
  final dex = <String>[];
  for (final apk in apks) {
    manifests.add(await analyze(apk, ['manifest', 'print']));
    final input = InputFileStream(apk);
    try {
      final archive = ZipDecoder().decodeStream(input);
      if (archive.any(
        (file) => RegExp(r'^classes\d*\.dex$').hasMatch(file.name),
      )) {
        dex.add(await analyze(apk, ['dex', 'packages', '--defined-only']));
      }
    } finally {
      await input.close();
    }
  }
  final missing =
      manifests
          .expand((manifest) => missingComponents(manifest, dex.join('\n')))
          .toSet()
          .toList()
        ..sort();
  if (missing.isNotEmpty) {
    throw StateError(missing.join('\n'));
  }
  stdout.writeln('PASS: all enabled manifest component classes are packaged');
}

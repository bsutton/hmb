import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:path/path.dart';
import 'package:pub_release/pub_release.dart';

void updateAndroidVersion(Version version) {
  final filePath = join(
    DartProject.self.pathToProjectRoot,
    'android',
    'version.properties',
  );
  final properties = _loadProperties(filePath);

  // Get current version code
  var versionCode = int.tryParse(properties['flutter.versionCode'] ?? '1') ?? 1;

  // Increment version code
  versionCode += 1;

  // Update the property
  properties['flutter.versionCode'] = versionCode.toString();

  properties['flutter.versionName'] = version.toString();

  // Save the updated properties back to the file
  _saveProperties(filePath, properties);

  print(green('Updated flutter.versionCode to $versionCode'));
}

Map<String, String> _loadProperties(String filePath) {
  final properties = <String, String>{};
  final file = File(filePath);
  if (file.existsSync()) {
    final lines = file.readAsLinesSync();
    for (final line in lines) {
      if (line.contains('=')) {
        final parts = line.split('=');
        if (parts.length == 2) {
          properties[parts[0].trim()] = parts[1].trim();
        }
      }
    }
  }
  return properties;
}

void _saveProperties(String filePath, Map<String, String> properties) {
  final file = File(filePath);
  final buffer = StringBuffer();
  properties.forEach((key, value) {
    buffer.writeln('$key=$value');
  });
  file.writeAsStringSync(buffer.toString());
}

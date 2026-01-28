import 'dart:io';

/// A simple Dart script to prepend a copyright and license header
/// to all Dart files
/// Usage: dart run add_copyright.dart from your root_directory

void main(List<String> args) {
  final rootDir = args.isNotEmpty ? Directory(args[0]) : Directory.current;
  if (!rootDir.existsSync()) {
    stderr.writeln('Directory not found: ${rootDir.path}');
    exit(1);
  }

  // Define your copyright and license block here.
  const header = '''
/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, 
      with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for 
    third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/
''';

  // Recursively find all .dart files, excluding any under a ".history"
  // directory
  final dartFiles = <File>[];
  for (final entity in rootDir.listSync(recursive: true, followLinks: false)) {
    if (entity is File &&
        entity.path.endsWith('.dart') &&
        !entity.path.split(Platform.pathSeparator).contains('.history')) {
      dartFiles.add(entity);
    }
  }

  for (final file in dartFiles) {
    final content = file.readAsStringSync();
    // Skip if header already present
    if (content.contains('Copyright © OnePub IP Pty Ltd')) {
      stdout.writeln('Skipping ${file.path} (already has header)');
      continue;
    }

    // Prepend header to top of file
    final updated = StringBuffer()
      ..write(header)
      ..write('\n')
      ..write(content);
    file.writeAsStringSync(updated.toString());
    stdout.writeln('Updated ${file.path}');
  }

  stdout.writeln('Done. Processed ${dartFiles.length} Dart file(s).');
}

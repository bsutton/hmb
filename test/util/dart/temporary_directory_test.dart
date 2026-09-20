import 'dart:io';

import 'package:hmb/util/dart/paths_dart.dart' as paths;
import 'package:test/test.dart';

void main() {
  test('recreates a temporary directory removed by cache cleanup', () async {
    final path = await paths.getTemporaryDirectory();
    final directory = Directory(path);
    expect(directory.existsSync(), isTrue);
    await directory.delete(recursive: true);

    expect(await paths.getTemporaryDirectory(), path);
    expect(directory.existsSync(), isTrue);
    final output = File('$path/assignment.pdf');
    await output.writeAsString('temporary output');
    expect(await output.readAsString(), 'temporary output');
    await directory.delete(recursive: true);
  });
}

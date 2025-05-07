import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  testWidgets('paths flutter ...', (tester) async {
    print('starting on ${Platform.operatingSystem}');

    final path = await getApplicationDocumentsDirectory();
    print('path: $path');
  });
}

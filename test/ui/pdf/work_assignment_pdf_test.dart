@Tags(['flutter'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/work_assignment.dart';
import 'package:hmb/ui/crud/work_assignment/generate_work_assignment_pdf.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../database/management/db_utility_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('assignment PDF uses the platform temporary directory', () async {
    final directory = await Directory.systemTemp.createTemp('hmb_assignment_');
    final provider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _PathProvider(directory.path);
    await setupTestDb();
    try {
      final assignment = WorkAssignment.forInsert(
        jobId: 999999,
        supplierId: 999999,
        contactId: 999999,
      );
      final file = await generateWorkAssignmentPdf(assignment);
      expect(file.parent.path, directory.path);
      expect(latin1.decode(await file.readAsBytes()), startsWith('%PDF-'));
    } finally {
      await tearDownTestDb();
      PathProviderPlatform.instance = provider;
      await directory.delete(recursive: true);
    }
  });
}

class _PathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;

  _PathProvider(this.path);

  @override
  Future<String?> getTemporaryPath() async => path;
}

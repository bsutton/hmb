import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_tool.dart';
import 'package:hmb/entity/tool.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test(
    'tool location and borrower persist, clear and can be searched',
    () async {
      final dao = DaoTool();
      final tool = Tool.forInsert(
        name: 'Test drill',
        location: 'Example site',
        lentTo: 'Example borrower',
      );
      await dao.insert(tool);
      final saved = (await dao.getById(tool.id))!;
      expect(saved.location, 'Example site');
      expect(saved.lentTo, 'Example borrower');
      expect(
        (await dao.getByFilter('Example site')).map((t) => t.id),
        contains(tool.id),
      );
      expect(
        (await dao.getByFilter('Example borrower')).map((t) => t.id),
        contains(tool.id),
      );
      await dao.update(saved.copyWith(location: 'Workshop', lentTo: ''));
      expect((await dao.getById(tool.id))!.lentTo, isEmpty);
      final plain = Tool.forInsert(name: 'Existing-style tool');
      await dao.insert(plain);
      expect((await dao.getById(plain.id))!.location, isEmpty);
    },
  );
}

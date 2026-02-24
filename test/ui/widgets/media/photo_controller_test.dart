import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/widgets/media/photo_controller.dart';
import 'package:hmb/util/dart/photo_meta.dart';
import 'package:money2/money2.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('saveComment persists and reloads task photo comments', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: Money.fromInt(10000, isoCode: 'AUD'),
      summary: 'Photo comment job',
    );

    final task = Task.forInsert(
      jobId: job.id,
      name: 'Comment Task',
      description: 'Task with a photo',
      status: TaskStatus.awaitingApproval,
    );
    await DaoTask().insert(task);

    final photo = Photo.forInsert(
      parentId: task.id,
      parentType: ParentType.task,
      filename: 'task-photo.jpg',
      comment: 'Original comment',
    );
    await DaoPhoto().insert(photo);

    final controller = PhotoController<Task>(
      parent: task,
      parentType: ParentType.task,
    );
    await controller.load();

    final metas = await controller.photos;
    expect(metas, hasLength(1));
    expect(controller.commentController(metas.first).text, 'Original comment');

    // Use a detached PhotoMeta instance with the same photo id to verify
    // saveComment resolves the entry by id, not object identity.
    final detached = PhotoMeta(
      photo: photo.copyWith(comment: photo.comment),
      title: task.name,
      comment: photo.comment,
    );
    controller.commentController(detached).text = 'Updated comment';
    await controller.saveComment(detached);

    final reloadedPhoto = await DaoPhoto().getById(photo.id);
    expect(reloadedPhoto, isNotNull);
    expect(reloadedPhoto!.comment, 'Updated comment');

    final controller2 = PhotoController<Task>(
      parent: task,
      parentType: ParentType.task,
    );
    await controller2.load();
    final reloadedMetas = await controller2.photos;
    expect(reloadedMetas, hasLength(1));
    expect(
      controller2.commentController(reloadedMetas.first).text,
      'Updated comment',
    );
  });
}

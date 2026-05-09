@Tags(['flutter'])
library;

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

  test('savePendingPhotos persists receipt photos after first save', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: Money.fromInt(10000, isoCode: 'AUD'),
      summary: 'Pending receipt photo job',
    );
    final supplier = Supplier.forInsert(
      name: 'Pending Photo Supplier',
      businessNumber: '',
      description: '',
      bsb: '',
      accountNumber: '',
      service: '',
    );
    await DaoSupplier().insert(supplier);

    final controller = PhotoController<Receipt>(
      parent: null,
      parentType: ParentType.receipt,
    );
    final pendingPhoto = Photo.forInsert(
      parentId: -1,
      parentType: ParentType.receipt,
      filename: 'pending-receipt.jpg',
      comment: 'Taken before save',
    );
    await controller.addPhoto(
      PhotoMeta(
        photo: pendingPhoto,
        title: 'Pending receipt',
        comment: pendingPhoto.comment,
      ),
    );

    expect(await DaoPhoto().getByParent(-1, ParentType.receipt), isEmpty);

    final receipt = Receipt.forInsert(
      receiptDate: DateTime(2026, 5, 9),
      jobId: job.id,
      supplierId: supplier.id,
      totalExcludingTax: Money.fromInt(10000, isoCode: 'AUD'),
      tax: Money.fromInt(1000, isoCode: 'AUD'),
      totalIncludingTax: Money.fromInt(11000, isoCode: 'AUD'),
    );
    await DaoReceipt().insert(receipt);

    controller.parent = receipt;
    await controller.savePendingPhotos();
    await controller.save();

    final photos = await DaoPhoto().getByParent(receipt.id, ParentType.receipt);
    expect(photos, hasLength(1));
    expect(photos.single.filename, 'pending-receipt.jpg');
    expect(photos.single.comment, 'Taken before save');
    expect(photos.single.parentId, receipt.id);
    expect(photos.single.parentType, ParentType.receipt);
  });
}

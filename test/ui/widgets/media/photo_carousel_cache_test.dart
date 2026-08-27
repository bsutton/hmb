@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/widgets/media/photo_carousel.dart';
import 'package:hmb/util/dart/photo_meta.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_view/photo_view.dart';

void main() {
  testWidgets('carousel displays the supplied cached photo path', (
    tester,
  ) async {
    final photo = Photo.forInsert(
      parentId: 1,
      parentType: ParentType.task,
      filename: 'evicted.jpg',
      comment: '',
    )..id = 42;
    final meta = PhotoMeta(photo: photo, title: 'Cached photo', comment: '');

    await tester.pumpWidget(
      MaterialApp(
        home: PhotoCarousel(
          photos: [meta],
          initialIndex: 0,
          photoPaths: const {42: '/tmp/cached-photo.jpg'},
        ),
      ),
    );

    final view = tester.widget<PhotoView>(find.byType(PhotoView));
    final provider = view.imageProvider! as FileImage;
    expect(provider.file.path, '/tmp/cached-photo.jpg');
  });
}

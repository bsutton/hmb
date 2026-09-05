@Tags(['flutter'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/widgets/media/full_screen_photo_view.dart';
import 'package:hmb/ui/widgets/media/photo_carousel.dart';
import 'package:hmb/util/dart/photo_meta.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_view/photo_view.dart';

void main() {
  testWidgets('zoom opens the current cached image and returns to gallery', (
    tester,
  ) async {
    late Directory directory;
    late File image;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('hmb-gallery-');
      image = File('${directory.path}/photo.png');
      await image.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a2ioAAAAASUVORK5CYII=',
        ),
      );
    });
    addTearDown(() => directory.delete(recursive: true));
    final photos = List.generate(
      2,
      (index) => PhotoMeta(
        photo: Photo.forInsert(
          parentId: 1,
          parentType: ParentType.task,
          filename: 'photo-$index.png',
          comment: '',
        )..id = index + 1,
        title: 'Photo $index',
        comment: '',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoCarousel(
          photos: photos,
          initialIndex: 1,
          photoPaths: {1: image.path, 2: image.path},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.zoom_in));
    for (var attempt = 0; attempt < 60; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      if (find.byType(FullScreenPhotoViewer).evaluate().isNotEmpty) {
        break;
      }
    }
    final viewer = tester.widget<FullScreenPhotoViewer>(
      find.byType(FullScreenPhotoViewer),
    );
    expect(viewer.imagePath, image.path);
    expect(viewer.title, 'Photo 1');
    Navigator.of(tester.element(find.byType(FullScreenPhotoViewer))).pop();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    expect(find.text('2/2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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

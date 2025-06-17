import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../../dao/dao_photo.dart';
import '../../../dao/dao_task.dart';
import '../../../entity/entity.g.dart';
import '../../../util/compute_manager.dart';
import '../../../util/photo_meta.dart';
import '../layout/hmb_placeholder.dart';
import 'photo_carousel.dart';
import 'thumbnail.dart';

class PhotoGallery extends StatelessWidget {
  PhotoGallery.forJob({required Job job, super.key}) {
    _fetchPhotos = () async {
      final tasks = await DaoTask().getTasksByJob(job.id);
      final meta = <PhotoMeta>[];
      for (final task in tasks) {
        meta.addAll(await DaoPhoto.getMetaByParent(task.id, ParentType.task));
      }
      return meta;
    };
  }

  PhotoGallery.forTask({required Task task, super.key}) {
    _fetchPhotos = () async => [
      ...await DaoPhoto.getMetaByParent(task.id, ParentType.task),
    ];
  }

  PhotoGallery.forReceipt({required Receipt receipt, super.key}) {
    _fetchPhotos = () async => [
      ...await DaoPhoto.getMetaByParent(receipt.id, ParentType.receipt),
    ];
  }

  /// the [filter] allows you to control what photos are returned.
  /// By default, if no [filter] is passed, then all photos for the tool
  /// are returned.
  PhotoGallery.forTool({
    required Tool tool,
    super.key,
    bool Function(Photo photo)? filter,
  }) {
    _fetchPhotos = () async =>
        (await DaoPhoto().getByParent(tool.id, ParentType.tool))
            .where((photo) => filter?.call(photo) ?? true)
            .map(
              (photo) => PhotoMeta(
                photo: photo,
                title: tool.name,
                comment: tool.description,
              ),
            )
            .toList();
  }
  final computeManager = ComputeManager<Thumbnail, Thumbnail>();

  late final Future<List<PhotoMeta>> Function() _fetchPhotos;

  @override
  Widget build(BuildContext context) => JuneBuilder(
    PhotoGalleryState.new,
    builder: (context) => FutureBuilderEx<List<PhotoMeta>>(
      waitingBuilder: (context) => const HMBPlaceHolder(height: 100),
      // ignore: discarded_futures
      future: _fetchPhotos(),
      builder: (context, photos) {
        if (photos!.isEmpty) {
          return const HMBPlaceHolder(height: 100);
        } else {
          return buildGallery(photos, context);
        }
      },
    ),
  );

  Widget buildGallery(List<PhotoMeta> photos, BuildContext context) => SizedBox(
    height: 100,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: photos
          .map(
            (photoMeta) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () async {
                  if (photoMeta.exists()) {
                    if (context.mounted) {
                      final index = photos.indexOf(photoMeta);
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => PhotoCarousel(
                            photos: photos,
                            initialIndex: index,
                          ),
                        ),
                      );
                    }
                  }
                },

                // onTap: () async {
                //   if (photoMeta.exists()) {
                //     // Fetch the task for this photo to get
                //     // the task name.
                //     if (context.mounted) {
                //       await FullScreenPhotoViewer.show(
                //           context: context,
                //           imagePath: photoMeta.absolutePathTo,
                //           title: photoMeta.title,
                //           comment: photoMeta.comment);
                //     }
                //   }
                // },
                child: FutureBuilderEx<Thumbnail?>(
                  // ignore: discarded_futures
                  future: _getThumbNail(photoMeta),
                  waitingBuilder: (context) => _showWaitingIcon(),
                  errorBuilder: (context, error) => _showMissingIcon(),

                  builder: (context, thumbnail) {
                    if (thumbnail == null) {
                      return _showMissingIcon();
                    } else {
                      return _showThumbnail(thumbnail);
                    }
                  },
                ),
              ),
            ),
          )
          .toList(),
    ),
  );

  Stack _showThumbnail(Thumbnail? thumbnail) => Stack(
    children: [
      Image.file(
        File(thumbnail!.pathToThumbNail),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 80,
          height: 80,
          color: Colors.grey,
          child: const Icon(Icons.broken_image, color: Colors.white, size: 40),
        ),
      ),
      const Positioned(
        bottom: 8,
        right: 0,
        child: ColoredBox(
          color: Colors.black45,
          child: Icon(Icons.zoom_out_map, color: Colors.white),
        ),
      ),
    ],
  );

  Container _showWaitingIcon() => Container(
    width: 80,
    height: 80,
    color: Colors.grey,
    child: const Icon(Icons.image, color: Colors.white, size: 40),
  );

  Container _showMissingIcon() => Container(
    width: 80,
    height: 80,
    color: Colors.grey,
    child: const Icon(Icons.error, color: Colors.white, size: 40),
  );

  static void notify() {
    June.getState(PhotoGalleryState.new).setState();
  }

  Future<Thumbnail?> _getThumbNail(PhotoMeta photoMeta) async {
    await photoMeta.resolve();
    if (photoMeta.exists()) {
      final thumbnail = await Thumbnail.fromMeta(photoMeta);
      await thumbnail.generate(computeManager);
      return thumbnail;
    } else {
      return null;
    }
  }
}

class PhotoGalleryState extends JuneState {}

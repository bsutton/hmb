/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';
import 'dart:io';

import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
import 'package:material_ui/material_ui.dart';

import '../../../cache/hmb_image_cache.dart';
import '../../../cache/image_cache_config.dart';
import '../../../dao/dao_photo.dart';
import '../../../dao/dao_task.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/compute_manager.dart';
import '../../../util/dart/photo_meta.dart';
import '../blocking_ui.dart';
import '../hmb_button.dart';
import '../hmb_toast.dart';
import '../layout/hmb_placeholder.dart';
import 'photo_carousel.dart';
import 'thumbnail.dart';

class PhotoGallery extends StatelessWidget {
  final computeManager = ComputeManager<Thumbnail, Thumbnail>();
  late final Future<List<PhotoMeta>> Function() _fetchPhotos;

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

  @override
  Widget build(BuildContext context) => JuneBuilder(
    PhotoGalleryState.new,
    builder: (context) => FutureBuilderEx<List<PhotoMeta>>(
      waitingBuilder: (context) => const HMBPlaceHolder(height: 100),
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
                  final paths = await _availablePhotoPaths(photos);
                  if (!paths.containsKey(photoMeta.photo.id) ||
                      !context.mounted) {
                    return;
                  }
                  final index = photos.indexOf(photoMeta);
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => PhotoCarousel(
                        photos: photos,
                        initialIndex: index,
                        photoPaths: paths,
                      ),
                    ),
                  );
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
                  future: _getThumbNail(photoMeta),
                  waitingBuilder: (context) => _showWaitingIcon(),
                  errorBuilder: (context, error) => _showFetchButton(photos),

                  builder: (context, thumbnail) {
                    if (thumbnail == null) {
                      return _showFetchButton(photos);
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

  Widget _showFetchButton(List<PhotoMeta> photos) => Container(
    width: 80,
    height: 80,
    color: Colors.grey,
    padding: const EdgeInsets.all(4),
    child: HMBButton.smallWithIcon(
      label: 'Fetch',
      hint: 'Fetch all photos in this gallery',
      icon: const Icon(Icons.cloud_download),
      onPressed: () async {
        try {
          await BlockingUI().runAndWait(
            () => _fetchGallery(photos),
            label: 'Fetching gallery photos',
          );
        } catch (error) {
          HMBToast.error('Unable to fetch gallery photos: $error');
        } finally {
          notify();
        }
      },
    ),
  );

  static void notify() {
    June.getState(PhotoGalleryState.new).setState();
  }

  Future<Thumbnail?> _getThumbNail(PhotoMeta photoMeta) async {
    final path = await _availablePhotoPath(photoMeta);
    if (path == null) {
      return null;
    }
    final thumbnail = await Thumbnail.fromSource(path);
    await thumbnail.generate(computeManager);
    return thumbnail;
  }

  Future<String?> _availablePhotoPath(PhotoMeta meta) async {
    await meta.resolve();
    if (meta.exists()) {
      return meta.absolutePathTo;
    }
    final cache = HMBImageCache();
    for (final variant in [
      ImageVariantType.general,
      ImageVariantType.raw,
      ImageVariantType.thumb,
    ]) {
      final path = await cache.getCachedVariantPathForMeta(
        meta: meta,
        imageVariant: variant,
      );
      if (path != null) {
        return path;
      }
    }
    return null;
  }

  Future<Map<int, String>> _availablePhotoPaths(List<PhotoMeta> photos) async {
    final paths = <int, String>{};
    for (final photo in photos) {
      final path = await _availablePhotoPath(photo);
      if (path != null) {
        paths[photo.photo.id] = path;
      }
    }
    return paths;
  }

  Future<void> _fetchGallery(List<PhotoMeta> photos) async {
    final cache = HMBImageCache();
    for (final photo in photos) {
      if (await _availablePhotoPath(photo) != null) {
        continue;
      }
      await cache.getVariantPathForMeta(
        meta: photo,
        imageVariant: ImageVariantType.raw,
        cacheRaw: true,
      );
    }
  }
}

class PhotoGalleryState extends JuneState {}

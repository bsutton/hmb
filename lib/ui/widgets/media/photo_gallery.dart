import 'dart:async';
import 'dart:io';

import 'package:dcli_core/dcli_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:image/image.dart' as img;
import 'package:june/june.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../dao/dao_photo.dart';
import '../../../dao/dao_task.dart';
import '../../../entity/_index.g.dart';
import '../../../entity/tool.dart';
import '../../../util/compute_manager.dart';
import '../../../util/exceptions.dart';
import '../../../util/photo_meta.dart';
import '../layout/hmb_placeholder.dart';
import 'full_screen_photo_view.dart';

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
    _fetchPhotos = () async =>
        [...await DaoPhoto.getMetaByParent(task.id, ParentType.task)];
  }

  /// the [filter] allows you to control what photos are returned.
  /// By default, if no [filter] is passed, then all photos for the tool
  /// are returned.
  PhotoGallery.forTool(
      {required Tool tool, super.key, bool Function(Photo photo)? filter}) {
    _fetchPhotos = () async =>
        (await DaoPhoto().getByParent(tool.id, ParentType.tool))
            .where((photo) => filter?.call(photo) ?? true)
            .map((photo) => PhotoMeta(
                photo: photo, title: tool.name, comment: tool.description))
            .toList();
  }
  final computeManager = ComputeManager();

  late final Future<List<PhotoMeta>> Function() _fetchPhotos;

  @override
  Widget build(BuildContext context) => JuneBuilder(PhotoGalleryState.new,
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
          }));

  Widget buildGallery(List<PhotoMeta> photos, BuildContext context) => SizedBox(
        height: 100,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: photos
              .map((photoMeta) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: GestureDetector(
                      onTap: () async {
                        if (photoMeta.exists()) {
                          // Fetch the task for this photo to get
                          // the task name.
                          if (context.mounted) {
                            await FullScreenPhotoViewer.show(
                                context: context,
                                imagePath: photoMeta.absolutePathTo,
                                title: photoMeta.title,
                                comment: photoMeta.comment);
                          }
                        }
                      },
                      child: FutureBuilderEx<String?>(
                        // ignore: discarded_futures
                        future: _getThumbnailPath(computeManager, photoMeta),

                        waitingBuilder: (context) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey,
                          child: const Icon(
                            Icons.image,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        errorBuilder: (context, error) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey,
                          child: const Icon(
                            Icons.error,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),

                        builder: (context, path) => Stack(
                          children: [
                            Image.file(
                              File(path!),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey,
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                            const Positioned(
                              bottom: 8,
                              right: 0,
                              child: ColoredBox(
                                color: Colors.black45,
                                child: Icon(
                                  Icons.zoom_out_map,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      );

  static void notify() {
    June.getState(PhotoGalleryState.new).setState();
  }
}

class PhotoGalleryState extends JuneState {}

Future<String?> _getThumbnailPath(
    ComputeManager computeManager, PhotoMeta meta) async {
  await meta.resolve();

  final absolutePath = meta.absolutePathTo;
  final thumbnailDir = await _getThumbnailDirectory();
  final thumbnailPath =
      p.join(thumbnailDir, '${p.basenameWithoutExtension(absolutePath)}.jpg');

  if (!core.exists(absolutePath)) {
    throw InvalidPathException(absolutePath);
  }

  if (core.exists(thumbnailPath)) {
    return thumbnailPath;
  } else {
    // Generate thumbnail in a background isolate

    return computeManager.enqueueCompute(_generateThumbnail,
        ThumbnailPaths(source: absolutePath, target: thumbnailPath));
  }
}

class ThumbnailPaths {
  ThumbnailPaths({required this.source, required this.target});
  String source;
  String target;
}

// Function to generate a thumbnail (to be run in a background isolate)
Future<String?> _generateThumbnail(ThumbnailPaths paths) async {
  print('generating thumbnail: ${paths.source}');

  final imageFile = File(paths.source);
  if (!core.exists(paths.source)) {
    return null;
  }

  final image = img.decodeImage(imageFile.readAsBytesSync());
  if (image == null) {
    return null;
  }

  final thumbnail = img.copyResize(image, width: 80, height: 80);
  File(paths.target).writeAsBytesSync(img.encodeJpg(thumbnail));
  print('completed thumbnail: ${paths.source}');
  return paths.target;
}

// Helper function to get the thumbnail directory
Future<String> _getThumbnailDirectory() async {
  final tempDir = await getTemporaryDirectory();
  final thumbnailDir = p.join(tempDir.path, 'thumbnails');
  Directory(thumbnailDir).createSync(recursive: true);
  return thumbnailDir;
}

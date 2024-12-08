import 'dart:io';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../../dao/dao_photo.dart';
import '../../../dao/dao_task.dart';
import '../../../entity/_index.g.dart';
import '../../../entity/tool.dart';
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

  /// the [filter] allow syou to control what photos are returned.
  /// By default if no [filter] is passed then all photos for the tool
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

  late final Future<List<PhotoMeta>> Function() _fetchPhotos;

  /// Show a list of photo thumbnails for the job.
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

  Widget buildGallery(List<PhotoMeta> photos, BuildContext context) =>
      FutureBuilderEx(
          // ignore: discarded_futures
          future: PhotoMeta.resolveAll(photos),
          builder: (context, resolved) => SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: resolved!.map((photoMeta) {
                    final file = File(photoMeta.absolutePathTo);
                    final isFileExist = file.existsSync();

                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: GestureDetector(
                        onTap: () async {
                          if (isFileExist) {
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
                        child: Stack(
                          children: [
                            if (isFileExist)
                              Image.file(
                                file,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                            else
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
                            if (isFileExist)
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
                    );
                  }).toList(),
                ),
              ));

  static void notify() {
    June.getState(PhotoGalleryState.new).setState();
  }

  // Future<void> _showFullScreenPhoto(BuildContext context, String imagePath,
  //     String taskName, String comment) async {
  //   await context.push('/photo_viewer', extra: {
  //     'imagePath': imagePath,
  //     'taskName': taskName,
  //     'comment': comment,
  //   });
  // }
}

class PhotoGalleryState extends JuneState {
  PhotoGalleryState();
}

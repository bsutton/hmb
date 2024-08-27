import 'dart:io';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';
import 'package:june/june.dart';

import '../dao/dao_photo.dart';
import '../dao/dao_task.dart';
import '../entity/job.dart';
import '../entity/photo.dart';
import 'hmb_placeholder.dart';

class PhotoGallery extends StatelessWidget {
  const PhotoGallery({required this.job, super.key});

  final Job job;

  /// Show a list of photo thumbnails for the job.
  @override
  Widget build(BuildContext context) => JuneBuilder(PhotoGalleryState.new,
      builder: (context) => FutureBuilderEx<List<Photo>>(
          waitingBuilder: (context) => const HMBPlaceHolder(height: 100),
          // ignore: discarded_futures
          future: _fetchTaskPhotos(),
          builder: (context, photos) {
            if (photos!.isEmpty) {
              return const HMBPlaceHolder(height: 100);
            } else {
              return buildGallery(photos, context);
            }
          }));

  SizedBox buildGallery(List<Photo> photos, BuildContext context) => SizedBox(
        height: 100,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: photos.map((photo) {
            final file = File(photo.filePath);
            final isFileExist = file.existsSync();

            return Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () async {
                  if (isFileExist) {
                    // Fetch the task for this photo to get the task name.
                    final task = await DaoTask().getById(photo.taskId);
                    if (context.mounted) {
                      await _showFullScreenPhoto(
                          context, photo.filePath, task!.name, photo.comment);
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
      );

  Future<List<Photo>> _fetchTaskPhotos() async {
    final tasks = await DaoTask().getTasksByJob(job.id);
    final photos = <Photo>[];
    for (final task in tasks) {
      final taskPhotos = await DaoPhoto().getByTask(task.id);
      photos.addAll(taskPhotos);
    }
    return photos;
  }

  static void notify() {
    June.getState(PhotoGalleryState.new).setState();
  }

  Future<void> _showFullScreenPhoto(BuildContext context, String imagePath,
      String taskName, String comment) async {
    await context.push('/photo_viewer', extra: {
      'imagePath': imagePath,
      'taskName': taskName,
      'comment': comment,
    });
  }
}

class PhotoGalleryState extends JuneState {
  PhotoGalleryState();
}

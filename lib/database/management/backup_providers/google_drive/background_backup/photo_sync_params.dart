// lib/src/services/photo_sync_params.dart
import 'dart:isolate';

import 'package:path/path.dart';

import '../../../../../dao/dao.g.dart';
import '../../../../../entity/job.dart';
import '../../../../../entity/photo.dart';
import '../../../../../entity/task.dart';
import '../../../../../util/photo_meta.dart';

/// A simple payload representing a photo record for syncing.
class PhotoPayload {
  const PhotoPayload({
    required this.id,
    required this.absolutePathToPhoto,
    required this.createdAt,
    required this.jobSummary,
    required this.taskName,
    required this.jobId,
    required this.taskId,
    required this.pathToCloudStorage,
  });

  static Future<PhotoPayload> fromPhoto(Photo photo) async {
    final task = await DaoTask().getForPhoto(photo);
    final job = await DaoJob().getJobForTask(task!.id);

    final absolutePathToPhoto = await PhotoMeta.getAbsolutePath(photo);

    final storagePath = _buildStoragePath(job!, task, absolutePathToPhoto);
    return PhotoPayload(
      id: photo.id,
      absolutePathToPhoto: absolutePathToPhoto,
      createdAt: photo.createdDate,

      jobId: job.id,
      jobSummary: job.summary,
      taskId: task.id,
      taskName: task.name,
      pathToCloudStorage: storagePath,
    );
  }

  /// id of photo entity in db
  final int id;
  final String absolutePathToPhoto;
  final DateTime createdAt;
  final String jobSummary;
  final String taskName;
  final int jobId;
  final int taskId;

  /// The path to the cloud storage where this phto
  /// will be stored.
  final String pathToCloudStorage;

  static String sanitize(String input) =>
      input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();

  static String _buildStoragePath(
    Job job,
    Task task,
    String absolutePathToPhoto,
  ) {
    // Build the new folder structure
    final jobName = sanitize(job.summary);
    final taskName = sanitize(task.name);
    final jobFolderName = 'Job ${job.id} - $jobName';
    final taskFolderName = 'Task ${task.id} - $taskName';

    return join('photos', jobFolderName, taskFolderName, basename(absolutePathToPhoto));
  }
}

/// Parameters passed into the isolate for photo syncing.
class PhotoSyncParams {
  PhotoSyncParams({
    required this.sendPort,
    required this.authHeaders,
    required this.photos,
  });
  final SendPort sendPort;
  final Map<String, String> authHeaders;
  final List<PhotoPayload> photos;
}

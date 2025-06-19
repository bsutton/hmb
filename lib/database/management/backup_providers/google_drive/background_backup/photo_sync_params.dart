// lib/src/services/photo_sync_params.dart
import 'dart:isolate';

import 'package:path/path.dart';

import '../../../../../dao/dao.g.dart';
import '../../../../../entity/photo.dart';
import '../../../../../util/format.dart';
import '../../../../../util/photo_meta.dart';

/// A simple payload representing a photo record for syncing.
class PhotoPayload {
  const PhotoPayload({
    required this.id,
    required this.absolutePathToPhoto,
    required this.createdAt,
    // required this.jobSummary,
    // required this.taskName,
    // required this.jobId,
    // required this.taskId,
    required this.pathToCloudStorage,
  });

  static Future<PhotoPayload> fromPhoto(Photo photo) async {
    String storagePath;
    switch (photo.parentType) {
      case ParentType.task:
        storagePath = await _getPathForTask(photo);
      case ParentType.tool:
        storagePath = await _getPathForTool(photo);
      case ParentType.receipt:
        storagePath = await _getPathForReceipt(photo);
    }
    final absolutePathToPhoto = await PhotoMeta.getAbsolutePath(photo);
    return PhotoPayload(
      id: photo.id,
      absolutePathToPhoto: absolutePathToPhoto,
      createdAt: photo.createdDate,

      // jobId: job.id,
      // jobSummary: job.summary,
      // taskId: task.id,
      // taskName: task.name,
      pathToCloudStorage: storagePath,
    );
  }

  /// id of photo entity in db
  final int id;
  final String absolutePathToPhoto;
  final DateTime createdAt;
  // final String jobSummary;
  // final String taskName;
  // final int jobId;
  // final int taskId;

  /// The path to the cloud storage where this phto
  /// will be stored.
  final String pathToCloudStorage;

  static String sanitize(String input) =>
      input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();

  static Future<String> _getPathForTask(Photo photo) async {
    final task = await DaoTask().getForPhoto(photo);
    final job = await DaoJob().getJobForTask(task!.id);

    final absolutePathToPhoto = await PhotoMeta.getAbsolutePath(photo);

    final jobName = sanitize(job!.summary);
    final taskName = sanitize(task.name);
    final jobFolderName = 'Job ${job.id} - $jobName';
    final taskFolderName = 'Task ${task.id} - $taskName';

    return join(
      'photos',
      'jobs',
      jobFolderName,
      taskFolderName,
      basename(absolutePathToPhoto),
    );
  }

  static Future<String> _getPathForReceipt(Photo photo) async {
    final receipt = await DaoReceipt().getById(photo.parentId);

    final job = await DaoJob().getJobForTask(receipt!.jobId);

    final absolutePathToPhoto = await PhotoMeta.getAbsolutePath(photo);

    final jobName = sanitize(job!.summary);
    final receiptDate = formatDate(receipt.receiptDate, format: 'y-M-d');
    final jobFolderName = 'Job ${job.id} - $jobName';
    final receiptFolderName = 'Receipt ${receipt.id} - $receiptDate';

    return join(
      'photos',
      'receipts',
      jobFolderName,
      receiptFolderName,
      basename(absolutePathToPhoto),
    );
  }

  static Future<String> _getPathForTool(Photo photo) async {
    final tool = await DaoTool().getById(photo.parentId);
    final category = await DaoCategory().getById(tool!.categoryId);

    final absolutePathToPhoto = await PhotoMeta.getAbsolutePath(photo);

    final toolName = sanitize(tool.name);
    final toolCategory = category?.name ?? 'Uncategorised';
    final toolFolderName = 'tool ${tool.id} - $toolName';

    final String prefix;
    if (photo.id == tool.serialNumberPhotoId) {
      prefix = 'serial-no-';
    } else if (photo.id == tool.receiptPhotoId) {
      prefix = 'receipt-';
    } else {
      prefix = 'tool-';
    }

    return join(
      'photos',
      'tools',
      toolCategory,
      toolFolderName,
      '$prefix${basename(absolutePathToPhoto)}',
    );
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

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

// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:dcli_core/dcli_core.dart' as core;
import 'package:path/path.dart' as p;

import '../../dao/dao_category.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_receipt.dart';
import '../../dao/dao_task.dart';
import '../../dao/dao_tool.dart';
import '../../entity/photo.dart';
import '../dart/format.dart';
import '../dart/paths.dart';

class PhotoMeta {
  final Photo photo;
  final String title;
  String? comment;
  String? _absolutePath;

  PhotoMeta({required this.photo, required this.title, required this.comment});

  PhotoMeta.fromPhoto({required this.photo})
    : comment = photo.comment,
      title = '';

  String get absolutePathTo {
    assert(_absolutePath != null, 'You must call the resolve method first');

    return _absolutePath!;
  }

  Future<String> resolve() async =>
      _absolutePath = await getAbsolutePath(photo);

  /// returns the absolute path to where the photo is stored.
  static Future<String> getAbsolutePath(Photo photo) async =>
      p.join(await getPhotosRootPath(), photo.filename);

  /// Resolves all of the file paths into absolute file paths.
  static Future<List<PhotoMeta>> resolveAll(List<PhotoMeta> photos) async {
    for (final meta in photos) {
      await meta.resolve();
    }
    return photos;
  }

  /// The path to the cloud storage where this photo
  /// will be stored.
  /// This path is relative to the 'hmb/photo' folder.
  /// In debug mode it will be relative to 'hmb/debug/photo'.
  Future<Path> get cloudStoragePath async => switch (photo.parentType) {
    ParentType.task => await _getPathForTask(photo),
    ParentType.tool => _getPathForTool(photo),
    ParentType.receipt => _getPathForReceipt(photo),
  };

  bool exists() => core.exists(absolutePathTo);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PhotoMeta && photo.id == other.photo.id;
  }

  @override
  int get hashCode => photo.id.hashCode;

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

    return p.join(
      'jobs',
      jobFolderName,
      taskFolderName,
      p.basename(absolutePathToPhoto),
    );
  }

  static Future<String> _getPathForReceipt(Photo photo) async {
    final receipt = await DaoReceipt().getById(photo.parentId);

    final job = await DaoJob().getById(receipt!.jobId);

    final absolutePathToPhoto = await PhotoMeta.getAbsolutePath(photo);

    final jobName = sanitize(job!.summary);
    final receiptDate = formatDate(receipt.receiptDate, format: 'y-M-d');
    final jobFolderName = 'Job ${job.id} - $jobName';
    final receiptFolderName = 'Receipt ${receipt.id} - $receiptDate';

    return p.join(
      'receipts',
      jobFolderName,
      receiptFolderName,
      p.basename(absolutePathToPhoto),
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

    return p.join(
      'tools',
      toolCategory,
      toolFolderName,
      '$prefix${p.basename(absolutePathToPhoto)}',
    );
  }

  /// Returns the legacy thumbnail path if it exists; otherwise null.
  Future<String?> legacyThumbnailPathFor() async {
    await resolve();
    final tmp = await getTemporaryDirectory();
    final legacyDir = p.join(tmp, 'thumbnails');
    final name = '${p.basenameWithoutExtension(absolutePathTo)}.jpg';
    final full = p.join(legacyDir, name);
    return core.exists(full) ? full : null;
  }
}

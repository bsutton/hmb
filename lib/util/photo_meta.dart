// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:dcli_core/dcli_core.dart' as core;
import 'package:path/path.dart';

import '../../../../util/paths.dart'
    if (dart.library.ui) '../../../../util/paths_flutter.dart';
import '../entity/photo.dart';

class PhotoMeta {
  PhotoMeta({required this.photo, required this.title, required this.comment});

  PhotoMeta.fromPhoto({required this.photo})
    : comment = photo.comment,
      title = '';

  final Photo photo;
  final String title;
  String? comment;
  String? _absolutePath;

  String get absolutePathTo {
    assert(_absolutePath != null, 'You must call the resolve method first');

    return _absolutePath!;
  }

  Future<String> resolve() async =>
      _absolutePath = await getAbsolutePath(photo);

  /// returns the absolute path to where the photo is stored.
  static Future<String> getAbsolutePath(Photo photo) async =>
      join(await getPhotosRootPath(), photo.filePath);

  /// Resolves all of the file paths into absolute file paths.
  static Future<List<PhotoMeta>> resolveAll(List<PhotoMeta> photos) async {
    for (final meta in photos) {
      await meta.resolve();
    }
    return photos;
  }

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
}

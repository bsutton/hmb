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
      _absolutePath = join(await getPhotosRootPath(), photo.filePath);

  /// Resolves all of the file paths into absolute file paths.
  static Future<List<PhotoMeta>> resolveAll(List<PhotoMeta> photos) async {
    for (final meta in photos) {
      await meta.resolve();
    }
    return photos;
  }

  bool exists() => core.exists(absolutePathTo);
}

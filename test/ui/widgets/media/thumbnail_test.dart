import 'package:dcli/dcli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/photo.dart';
import 'package:hmb/ui/widgets/media/thumbnail.dart';
import 'package:hmb/util/compute_manager.dart';
import 'package:hmb/util/photo_meta.dart';
import 'package:path/path.dart';

void main() {
  testWidgets('thumbnail ...', (tester) async {
    final pathToPhoto = join(
      DartProject.self.pathToTestDir,
      'fixture',
      'photo',
      'sample_640x426.jpeg',
    );

    final photo = Photo.forInsert(
      parentId: 1,
      parentType: 'None',
      lastBackupDate: DateTime.now(),
      comment: 'None',
      filePath: pathToPhoto,
    );
    final meta = PhotoMeta.fromPhoto(photo: photo);

    final thumbnail = await Thumbnail.fromMeta(meta);
    print('meta returned');

    final computeManager = ComputeManager<Thumbnail, Thumbnail>();

    // await thumbnail.generate(computeManager);
  });
}

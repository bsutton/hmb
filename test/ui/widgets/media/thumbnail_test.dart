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

// ignore_for_file: unused_local_variable

import 'package:dcli/dcli.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/widgets/media/thumbnail.dart';
import 'package:hmb/util/dart/compute_manager.dart';
import 'package:hmb/util/dart/photo_meta.dart';
import 'package:path/path.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return '.';
          }
          if (methodCall.method == 'getTemporaryDirectory') {
            return '.';
          }
          return null;
        });
  });

  testWidgets('thumbnail ...', (tester) async {
    final pathToPhoto = join(
      DartProject.self.pathToTestDir,
      'fixture',
      'photos',
      'sample_640×426.jpeg',
    );

    final photo = Photo.forInsert(
      parentId: 1,
      parentType: ParentType.task,
      lastBackupDate: DateTime.now(),
      comment: 'None',
      filename: pathToPhoto,
    );
    final meta = PhotoMeta.fromPhoto(photo: photo);

    final thumbnail = await Thumbnail.fromMeta(meta);
    print('meta returned');

    final computeManager = ComputeManager<Thumbnail, Thumbnail>();

    // await thumbnail.generate(computeManager);
  });
}

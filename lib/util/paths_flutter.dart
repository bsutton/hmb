import 'package:path_provider/path_provider.dart';

/// Device specific to where all photos are stored for HMB.
Future<String> get photosRootPath async =>
    (await getApplicationDocumentsDirectory()).path;

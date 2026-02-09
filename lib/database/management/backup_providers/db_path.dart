import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

Future<String> pathToDatabase(String dbFilename) async =>
    join((await getApplicationDocumentsDirectory()).path, dbFilename);

import 'dart:ui';

import '../../util/flutter/hex_to_color.dart';
import '../job_status.dart';

extension JobStatusEx on JobStatus {
  Color getColour() => hexToColor(colorCode);
}

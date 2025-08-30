import 'package:flutter/material.dart';

import '../job_activity.dart';

extension JobActivityStatusEx on JobActivityStatus {
  Color get color => switch (statusColour) {
    JobActivityStatusColor.orange => Colors.orange,
    JobActivityStatusColor.blue => Colors.blue,
    JobActivityStatusColor.green => Colors.green,
  };
}

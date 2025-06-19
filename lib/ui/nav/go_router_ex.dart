import 'dart:async';

import 'package:go_router/go_router.dart';

extension GoRouterExtension on GoRouter {
  void clearStackAndNavigate(String location) {
    while (canPop()) {
      pop();
    }
    unawaited(pushReplacement(location));
  }
}

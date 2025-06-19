// lib/ui/widgets/splash_redirector.dart
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';
import 'package:june/june.dart';

import '../widgets/splash_screen.dart';
import 'app_lauch_state.dart';
import 'go_router_ex.dart';

class SplashRouter extends StatelessWidget {
  const SplashRouter({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
    future: _bootstrap(context),
    waitingBuilder: (_) => const SplashScreen(),
    builder: (_, _) => const SplashScreen(),
  );

  Future<void> _bootstrap(BuildContext context) async {
    final launchState = June.getState<AppLaunchState>(AppLaunchState.new);
    await launchState.initialize();

    if (!context.mounted) {
      return;
    }

    final next = launchState.isFirstRun ? '/system/wizard' : '/dashboard';
    // Replace splash route (not push) so it is removed
    GoRouter.of(context).clearStackAndNavigate(next);
  }
}

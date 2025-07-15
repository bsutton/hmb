/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

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

    final next = launchState.isFirstRun ? '/home/settings/wizard' : '/home';
    // Replace splash route (not push) so it is removed
    GoRouter.of(context).clearStackAndNavigate(next);
  }
}

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

import 'package:flutter/material.dart';

import '../../util/flutter/flutter_types.dart';
import '../../util/flutter/hmb_theme.dart';
import '../dialog/database_error_dialog.dart';
import 'layout/layout.g.dart';
import 'widgets.g.dart';

// ignore: omit_obvious_property_types
bool firstRun = false;

// re-use your blocking UI key
// final _blockingUIKey = GlobalKey();

class SplashScreen extends StatefulWidget {
  final AsyncContextCallback bootstrap;

  const SplashScreen({required this.bootstrap, super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Gradient background using your theme's primary and accent colors
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withSafeOpacity(0.8),
                  HMBColors.accent.withSafeOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Centered app branding
          Center(
            child: HMBColumn(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🍺 Hold My Beer',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Getting things ready...',
                  style: TextStyle(
                    fontSize: 18,
                    color: theme.colorScheme.onSurface.withSafeOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          // Blocking UI handles loading/errors
          BlockingUITransition(
            // key: _blockingUIKey,
            slowAction: () => widget.bootstrap(context),
            builder: (context, _) => const HMBEmpty(),
            errorBuilder: (context, error) =>
                DatabaseErrorDialog(error: error.toString()),
          ),
        ],
      ),
    );
  }
}

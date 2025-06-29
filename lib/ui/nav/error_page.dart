/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

/// A very simple error page widget.
///
/// [errorMessage] is displayed in the center of the screen.
/// [onRetry] is an optional callback for a “Try Again” button.
class ErrorPage extends StatelessWidget {
  const ErrorPage({required this.errorMessage, super.key, this.onRetry});

  final String errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('An Error Occurred')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The main error message
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
            const SizedBox(height: 24),

            // If onRetry is provided, show a retry button
            if (onRetry != null)
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
          ],
        ),
      ),
    ),
  );
}
